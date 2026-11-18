"""Render selected original parent-filtered sprites into caller-owned scratch.

Callable contract::

    folders, bounds = render_filtered(directory, {
        "effect": {"source_id": 6259, "parent_id": 6276,
                   "parent_source_frame": 48, "depth": 871,
                   "frames": [1, 2, 3, 4], "bake_basis": True}})

The selected parent frame/depth must be the original placement tag's birth,
not an arbitrary later frame. Original filters/CXFORM are cloned unchanged.
Translation is always zero. False bake_basis sets the whole matrix to identity;
True preserves its original basis. No SWF is saved. This module intentionally
does not import the runtime importer, so that importer can call it safely.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess

from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
WORKSPACE = PROJECT.parent
SWF = WORKSPACE / "leba" / "雷巴的冒险EX.swf"
FFDEC = WORKSPACE / "tools" / "swf" / "vendor" / "ffdec"

JAVA_RENDERER = r'''
import java.io.*;
import java.util.*;
import com.jpexs.decompiler.flash.SWF;
import com.jpexs.decompiler.flash.tags.*;
import com.jpexs.decompiler.flash.tags.base.*;
import com.jpexs.decompiler.flash.types.MATRIX;
import com.jpexs.decompiler.flash.types.RECT;
import com.jpexs.decompiler.flash.exporters.FrameExporter;
import com.jpexs.decompiler.flash.exporters.settings.SpriteExportSettings;
import com.jpexs.decompiler.flash.exporters.modes.SpriteExportMode;

class Act05FilteredRenderer {
 static PlaceObjectTypeTag placement(SWF swf,int parentId,int parentFrame,int depth,int sourceId) {
  Object parentObject=swf.getCharacter(parentId);
  if(!(parentObject instanceof DefineSpriteTag))throw new IllegalArgumentException("Parent is not a sprite: "+parentId);
  DefineSpriteTag parent=(DefineSpriteTag)parentObject;
  int frame=1;PlaceObjectTypeTag result=null;
  for(Tag tag:parent.getTags()) {
   if(tag instanceof ShowFrameTag){frame++;continue;}
   if(frame>parentFrame)break;
   if(frame==parentFrame && tag instanceof PlaceObjectTypeTag) {
    PlaceObjectTypeTag p=(PlaceObjectTypeTag)tag;
    if(p.getDepth()==depth && p.getCharacterId()==sourceId) {
     if(result!=null)throw new IllegalArgumentException("Ambiguous original placement: "+parentId+"/"+parentFrame+"/"+depth);
     result=p;
    }
   }
  }
  if(result==null)throw new IllegalArgumentException("No original birth placement for "+sourceId+" in "+parentId+"/"+parentFrame+" depth"+depth);
  return result;
 }

 public static void main(String[] args) throws Exception {
  SWF swf;
  try(InputStream input=new FileInputStream(args[0])){swf=new SWF(input,false);}
  for(int n=2;n<args.length;n++) {
   String[] pieces=args[n].split(":",-1);
   if(pieces.length!=7)throw new IllegalArgumentException("Malformed selected render specification");
   String key=pieces[0];int sourceId=Integer.parseInt(pieces[1]);
   int parentId=Integer.parseInt(pieces[2]),parentFrame=Integer.parseInt(pieces[3]),depth=Integer.parseInt(pieces[4]);
   boolean bakeBasis=pieces[5].equals("1");
   Object sourceObject=swf.getCharacter(sourceId);
   if(!(sourceObject instanceof DefineSpriteTag))throw new IllegalArgumentException("Source is not a sprite: "+sourceId);
   int actualCount=0;
   for(Tag tag:((DefineSpriteTag)sourceObject).getTags())if(tag instanceof ShowFrameTag)actualCount++;
   List<Integer> frames=new ArrayList<>();
   for(String token:pieces[6].split(",")) {
    int frame=Integer.parseInt(token);
    if(frame<1 || frame>actualCount)throw new IllegalArgumentException("Frame outside original source: "+sourceId+"/"+frame);
    frames.add(frame-1);
   }
   PlaceObjectTypeTag original=placement(swf,parentId,parentFrame,depth,sourceId);
   PlaceObjectTypeTag clone=(PlaceObjectTypeTag)((Tag)original).cloneTag();
   MATRIX originalMatrix=original.getMatrix()==null?new MATRIX():original.getMatrix();
   MATRIX matrix=bakeBasis?new MATRIX(originalMatrix):new MATRIX();
   matrix.translateX=0;matrix.translateY=0;
   clone.setMatrix(matrix);clone.setDepth(1);
   DefineSpriteTag wrapper=new DefineSpriteTag(swf);
   int wrapperId=swf.getNextCharacterId();wrapper.setCharacterId(wrapperId);
   wrapper.addTag((Tag)clone);
   for(int f=0;f<actualCount;f++)wrapper.addTag(new ShowFrameTag(swf));
   wrapper.setFrameCount(actualCount);swf.addTag(wrapper);swf.updateCharacters();
   wrapper.resetTimeline();swf.clearAllCache();
   RECT stroke=wrapper.getRectWithStrokes(),filtered=wrapper.getTimeline().getDisplayRectWithFilters();
   System.out.printf(Locale.ROOT,"FILTERED_BOUNDS %s %d %d %d %d %d %d %d %d%n",key,
      stroke.Xmin,stroke.Ymin,stroke.Xmax,stroke.Ymax,filtered.Xmin,filtered.Ymin,filtered.Xmax,filtered.Ymax);
   System.out.printf(Locale.ROOT,"FILTERED_MATRIX %s %.12f %.12f %.12f %.12f %d %d%n",key,
      matrix.hasScale?matrix.scaleX:1.0,matrix.hasRotate?matrix.rotateSkew0:0.0,
      matrix.hasRotate?matrix.rotateSkew1:0.0,matrix.hasScale?matrix.scaleY:1.0,matrix.translateX,matrix.translateY);
   File output=new File(args[1],key);
   if(!output.mkdirs())throw new IOException("Selected output directory already exists: "+output);
   new FrameExporter().exportSpriteFrames(null,output.getAbsolutePath(),swf,wrapperId,frames,1,
      new SpriteExportSettings(SpriteExportMode.PNG,1.0,1),null);
  }
 }
}
'''


def _digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def _validate(directory: Path, specs: dict) -> tuple[Path, dict]:
    directory = Path(directory).resolve()
    # Scratch may be in artifacts or an external temporary folder. Formal
    # author/generated/source locations are never valid destinations here.
    protected = [WORKSPACE / "res", WORKSPACE / "leba"]
    protected += [PROJECT / name for name in ("assets", "generated", "content", "scenes", "data", "scripts")]
    if any(directory == p.resolve() or directory.is_relative_to(p.resolve()) for p in protected):
        raise ValueError("Filtered rendering requires a scratch directory outside original/formal resource trees")
    if not isinstance(specs, dict) or not specs:
        raise ValueError("At least one explicit filtered render specification is required")
    selected = {}
    required = {"source_id", "parent_id", "parent_source_frame", "depth", "frames", "bake_basis"}
    for key, value in specs.items():
        if not isinstance(key, str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,128}", key):
            raise ValueError(f"Unsafe output key: {key!r}")
        if not isinstance(value, dict) or set(value) != required:
            raise ValueError(f"Specification {key} must contain exactly {sorted(required)}")
        for field in ("source_id", "parent_id", "parent_source_frame", "depth"):
            if type(value[field]) is not int or value[field] < 1:
                raise ValueError(f"{key}.{field} must be a positive integer")
        if type(value["bake_basis"]) is not bool:
            raise ValueError(f"{key}.bake_basis must be boolean")
        frames = value["frames"]
        if not isinstance(frames, list) or not frames or any(type(f) is not int or f < 1 for f in frames):
            raise ValueError(f"{key}.frames must contain positive source-frame integers")
        if frames != sorted(set(frames)):
            raise ValueError(f"{key}.frames must be sorted without duplicates")
        if (directory / key).exists():
            raise FileExistsError(f"Use a fresh selected output directory: {directory / key}")
        selected[key] = dict(value, frames=list(frames))
    if not SWF.is_file() or not (FFDEC / "ffdec.jar").is_file():
        raise FileNotFoundError("Original SWF or the existing FFDec installation is missing")
    return directory, selected


def render_filtered(directory: Path, specs: dict, *, source_setup: str = "", java_helpers: str = "") -> tuple[dict[str, Path], dict[str, dict]]:
    """Render all requested wrappers in one silent, headless Java process.

    Return folders[key] containing original ``<source_frame>.png`` names and
    bounds[key] with ``stroke_twips`` / ``filter_twips``. The helper, specs,
    stdout/stderr and checked provenance remain under the scratch directory.
    Raises on malformed specs, missing placements/frames, Java errors, stale
    outputs or unexpected pixel canvas sizes. Does not write formal resources.
    """
    directory, selected = _validate(directory, specs)
    directory.mkdir(parents=True, exist_ok=True)
    helper = directory / "Act05FilteredRenderer.java"
    renderer=JAVA_RENDERER
    if source_setup:
        renderer=renderer.replace(" public static void main(String[] args)",java_helpers+"\n public static void main(String[] args)",1)
        renderer=renderer.replace("  for(int n=2;n<args.length;n++) {","  SWF lookupSwf=new SWF(new FileInputStream(args[0]),false);\n"+source_setup+"\n  for(int n=2;n<args.length;n++) {",1)
        renderer=renderer.replace("placement(swf,parentId,parentFrame,depth,sourceId)","placement(lookupSwf,parentId,parentFrame,depth,sourceId)",1)
        renderer=renderer.replace("   clone.setMatrix(matrix);clone.setDepth(1);","   clone.setSwf(swf);clone.setMatrix(matrix);clone.setDepth(1);",1)
    helper.write_text(renderer, encoding="utf-8")
    (directory / "filtered_specs.json").write_text(json.dumps(selected, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    original_hash = _digest(SWF)
    command = ["java", "-Xmx2g", "-Djava.awt.headless=true", "-cp",
               str(FFDEC / "ffdec.jar") + os.pathsep + str(FFDEC / "lib" / "*"),
               str(helper), str(SWF), str(directory)]
    for key, s in selected.items():
        command.append(":".join([key, str(s["source_id"]), str(s["parent_id"]), str(s["parent_source_frame"]),
                                 str(s["depth"]), "1" if s["bake_basis"] else "0", ",".join(map(str, s["frames"]))]))
    result = subprocess.run(command, cwd=WORKSPACE, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=240)
    (directory / "filtered_stdout.log").write_text(result.stdout, encoding="utf-8")
    (directory / "filtered_stderr.log").write_text(result.stderr, encoding="utf-8")
    if result.returncode:
        raise RuntimeError(f"Filtered source rendering failed ({result.returncode}); see {directory / 'filtered_stderr.log'}\n{result.stdout[-3000:]}\n{result.stderr[-3000:]}")
    bounds = {}; matrices = {}; folders = {}; outputs = []
    for line in result.stdout.splitlines():
        if line.startswith("FILTERED_BOUNDS "):
            row = line.split(); numbers = list(map(int, row[2:]))
            if len(numbers) != 8 or row[1] not in selected or row[1] in bounds:
                raise RuntimeError("Unexpected/duplicate filtered bounds response")
            bounds[row[1]] = {"stroke_twips": numbers[:4], "filter_twips": numbers[4:]}
        elif line.startswith("FILTERED_MATRIX "):
            row = line.split(); matrices[row[1]] = list(map(float, row[2:]))
    if set(bounds) != set(selected) or set(matrices) != set(selected):
        raise RuntimeError("Incomplete selected filtered render result")
    for key, spec in selected.items():
        candidates = [p for p in (directory / key).iterdir() if p.is_dir() and p.name.startswith("DefineSprite_")]
        if len(candidates) != 1:
            raise RuntimeError(f"Expected one wrapper sprite folder for {key}, got {candidates}")
        folder = candidates[0]; folders[key] = folder
        if {p.name for p in folder.glob("*.png")} != {f"{f}.png" for f in spec["frames"]}:
            raise RuntimeError(f"Selected source PNG names differ for {key}")
        r = bounds[key]["filter_twips"]
        expected_size = (math.ceil((r[2] - r[0]) / 20), math.ceil((r[3] - r[1]) / 20))
        if not spec["bake_basis"] and matrices[key] != [1., 0., 0., 1., 0., 0.]:
            raise RuntimeError(f"Identity wrapper matrix was not applied: {key}: {matrices[key]}")
        if matrices[key][4:] != [0., 0.]:
            raise RuntimeError(f"Parent translation remains in wrapper: {key}")
        for f in spec["frames"]:
            path = folder / f"{f}.png"
            with Image.open(path) as image:
                if image.size != expected_size:
                    raise RuntimeError(f"Source canvas/bounds mismatch {key}/{f}: {image.size} != {expected_size}")
                alpha = image.convert("RGBA").getchannel("A").getbbox()
                outputs.append({"key":key,"source_frame":f,"path":path.relative_to(directory).as_posix(),
                                "size":list(image.size),"alpha_bounds":list(alpha) if alpha else None,"sha256":_digest(path)})
    if _digest(SWF) != original_hash:
        raise RuntimeError("Original SWF hash changed during readonly rendering")
    report = {"original_swf_sha256":original_hash,"original_swf_hash_unchanged":True,
              "renderer_sha256":_digest(helper),"specs":selected,"bounds":bounds,"baked_matrices":matrices,
              "outputs":outputs,"java_exit_code":result.returncode,
              "scope":"Static FFDec derivation only; no AS2 execution, gameplay verification or audio playback; original SWF never saved."}
    (directory / "filtered_provenance.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return folders, bounds


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--specs-json", type=Path)
    group.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    selected = {
        "e_depth871":dict(source_id=6259,parent_id=6276,parent_source_frame=48,depth=871,frames=[1,2,4],bake_basis=True),
        "e_depth879":dict(source_id=6259,parent_id=6276,parent_source_frame=64,depth=879,frames=[1,2,4],bake_basis=True),
        "w_identity":dict(source_id=6166,parent_id=6177,parent_source_frame=6,depth=1,frames=[1,7,14],bake_basis=False),
    } if args.self_test else json.loads(args.specs_json.read_text(encoding="utf-8"))
    folders, bounds = render_filtered(args.output, selected)
    print(json.dumps({"rendered_keys":list(folders),"selected_frames":sum(len(s["frames"]) for s in selected.values()),
                      "report":str(args.output.resolve()/"filtered_provenance.json")}, ensure_ascii=False))
