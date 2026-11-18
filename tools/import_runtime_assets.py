"""Derive the ticket 01/02 runtime subset from the read-only workspace sources.

No SWF, scripts, XML or complete frame library is copied into the game project.
Run from any directory with Python 3.11+, Pillow and Java 11+ available.
"""
from __future__ import annotations

import argparse
import contextlib
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
import re
from PIL import Image, __version__ as PILLOW_VERSION

PROJECT = Path(__file__).resolve().parents[1]
WORKSPACE = PROJECT.parent
SOURCES = WORKSPACE / "res"
ASSETS = PROJECT / "assets"
CATALOG = PROJECT / "data" / "asset_catalog.json"
SWF = WORKSPACE / "leba" / "雷巴的冒险EX.swf"
FFDEC = WORKSPACE / "tools" / "swf" / "vendor" / "ffdec"
EXPECTED_SWF_SHA256 = "afef4c43153780e9140eca7234b5af26c4a751596efefeb071d35428435a909d"
FROZEN_SELECTORS = [3572,3588,3597,3602,3610,3620,3631,3632,3641,3650,3659,3674,3678,3679,3688,3694,3725,3761,3763,4543,4632,4634,4765,4776]

BOUNDS_HELPER = r'''
import java.io.*;
import com.jpexs.decompiler.flash.SWF;
import com.jpexs.decompiler.flash.tags.base.BoundedTag;
import com.jpexs.decompiler.flash.types.RECT;
class Bounds {
 public static void main(String[] args) throws Exception {
  SWF swf = new SWF(new FileInputStream(args[0]), false);
  for (int i=1;i<args.length;i++) {
   int id=Integer.parseInt(args[i]);
   BoundedTag tag=(BoundedTag)swf.getCharacter(id);
   RECT r=tag.getRectWithStrokes();
   RECT f=tag.getRectWithFilters();
   System.out.printf("BOUNDS %d %d %d %d %d %d %d %d %d%n",id,r.Xmin,r.Ymin,r.Xmax,r.Ymax,f.Xmin,f.Ymin,f.Xmax,f.Ymax);
  }
 }
}
'''

UI_RENDERER = r'''
import java.io.*;
import java.util.*;
import com.jpexs.decompiler.flash.SWF;
import com.jpexs.decompiler.flash.tags.*;
import com.jpexs.decompiler.flash.tags.base.*;
import com.jpexs.decompiler.flash.types.*;
import com.jpexs.decompiler.flash.exporters.FrameExporter;
import com.jpexs.decompiler.flash.exporters.settings.SpriteExportSettings;
import com.jpexs.decompiler.flash.exporters.modes.SpriteExportMode;
class UiRenderer {
 static void readyFrame(SWF swf,int id,boolean panel) throws Exception {
  DefineSpriteTag s=(DefineSpriteTag)swf.getCharacter(id);boolean after=false;
  for(Tag t:s.getTags().toArrayList()) {
   boolean omit=after;
   if(t instanceof PlaceObjectTypeTag) {
    int child=((PlaceObjectTypeTag)t).getCharacterId();CharacterTag tag=swf.getCharacter(child);
    if(panel && (tag instanceof DefineEditTextTag || child==4112 || child==4118))omit=true;
    if(!panel && tag!=null && tag.getClass().getSimpleName().contains("MorphShape"))omit=true;
   }
   if(omit)s.removeTag(t);
   if(t instanceof ShowFrameTag)after=true;
  }
  s.setFrameCount(1);s.resetTimeline();s.setModified(true);
 }
 static DefineSpriteTag wrap(SWF swf,PlaceObjectTypeTag placement) throws Exception {
  DefineSpriteTag s=new DefineSpriteTag(swf);s.setCharacterId(swf.getNextCharacterId());
  s.addTag((Tag)placement);s.addTag(new ShowFrameTag(swf));s.setFrameCount(1);
  swf.addTag(s);swf.updateCharacters();return s;
 }
 static void selectedStaticPage(SWF swf,int id,int selected) throws Exception {
  DefineSpriteTag s=(DefineSpriteTag)swf.getCharacter(id);List<Tag> tags=new ArrayList<>();int frame=1;
  for(Tag t:s.getTags()) {
   if(t instanceof ShowFrameTag) {if(frame++==selected)break;continue;}
   if(t instanceof PlaceObjectTypeTag || t instanceof RemoveObjectTag || t instanceof RemoveObject2Tag)tags.add(t.cloneTag());
  }
  for(Tag t:s.getTags().toArrayList())s.removeTag(t);
  for(Tag t:tags)s.addTag(t);
  s.addTag(new ShowFrameTag(swf));s.setFrameCount(1);s.resetTimeline();s.setModified(true);
 }
 public static void main(String[] args) throws Exception {
  SWF swf=new SWF(new FileInputStream(args[0]),false);
  for(int n=2;n<args.length;n++) {
   String[] a=args[n].split(":");String key=a[0];int id=Integer.parseInt(a[1]);String mode=a[2];
   DefineSpriteTag s;int renderFrame=0;
   if(mode.equals("root41")) {
    PlaceObjectTypeTag found=null;int f=1;
    for(Tag t:swf.getTags()) {
     if(t instanceof ShowFrameTag)f++;
     if(f==41 && t instanceof PlaceObjectTypeTag && ((PlaceObjectTypeTag)t).getCharacterId()==id) {found=(PlaceObjectTypeTag)t;break;}
    }
    if(found==null)throw new IllegalStateException("Missing original root41 placement "+id);
    PlaceObjectTypeTag p=(PlaceObjectTypeTag)((Tag)found).cloneTag();
    MATRIX matrix=new MATRIX(p.getMatrix());matrix.translateX=0;matrix.translateY=0;
    p.setMatrix(matrix);p.setDepth(1);s=wrap(swf,p);
   } else if(mode.equals("panel_crt4_ready")) {
    for(int control:new int[]{4291,4292,4296,4300,4304,4308,4312,4316,4318,4322,4326,4330,4334,4337})readyFrame(swf,control,false);
    s=(DefineSpriteTag)swf.getCharacter(id);renderFrame=4;
    for(Tag t:s.getTags().toArrayList())if(t instanceof PlaceObjectTypeTag) {
     int child=((PlaceObjectTypeTag)t).getCharacterId();
     if(swf.getCharacter(child) instanceof DefineEditTextTag || child==4112 || child==4118)s.removeTag(t);
    }
    s.resetTimeline();s.setModified(true);
   } else if(mode.equals("panel_crt3_ready")) {
    for(int control:new int[]{4234,4238,4242,4246,4251,4255,4259,4263,4266,4267,4268,4272,4276,4283,4288,4229})readyFrame(swf,control,false);
    s=(DefineSpriteTag)swf.getCharacter(id);renderFrame=3;
    for(Tag t:s.getTags().toArrayList())if(t instanceof PlaceObjectTypeTag) {
     int child=((PlaceObjectTypeTag)t).getCharacterId();
     if(swf.getCharacter(child) instanceof DefineEditTextTag || child==4112 || child==4118)s.removeTag(t);
    }
    s.resetTimeline();s.setModified(true);
   } else if(mode.equals("panel_crt2_ready")) {
    for(int control:new int[]{4176,4178,4182,4185,4189,4191,4193,4197,4200,4201,4202,4206,4209,4213,4221,4227,4229})readyFrame(swf,control,false);
    s=(DefineSpriteTag)swf.getCharacter(id);renderFrame=2;
    for(Tag t:s.getTags().toArrayList())if(t instanceof PlaceObjectTypeTag) {
     int child=((PlaceObjectTypeTag)t).getCharacterId();
     if(swf.getCharacter(child) instanceof DefineEditTextTag || child==4112 || child==4118)s.removeTag(t);
    }
    s.resetTimeline();s.setModified(true);
   } else if(mode.equals("panel_crt1_ready")) {
    for(int control:new int[]{4121,4123,4125,4128,4130,4133,4136,4138,4140,4142,4144,4147,4149,4151,4155,4157,4165,4172})readyFrame(swf,control,false);
    s=(DefineSpriteTag)swf.getCharacter(id);renderFrame=1;
    for(Tag t:s.getTags().toArrayList())if(t instanceof PlaceObjectTypeTag) {
     int child=((PlaceObjectTypeTag)t).getCharacterId();
     if(swf.getCharacter(child) instanceof DefineEditTextTag || child==4112 || child==4118)s.removeTag(t);
    }
    s.resetTimeline();s.setModified(true);
   } else if(mode.startsWith("placement_")) {
    String[] modeParts=mode.split("_");int parent=Integer.parseInt(modeParts[1]),targetFrame=Integer.parseInt(modeParts[2]);
    PlaceObjectTypeTag found=null;int f=1;
    for(Tag t:((DefineSpriteTag)swf.getCharacter(parent)).getTags()) {
     if(t instanceof ShowFrameTag)f++;
     if(f==targetFrame && t instanceof PlaceObjectTypeTag && ((PlaceObjectTypeTag)t).getCharacterId()==id) {found=(PlaceObjectTypeTag)t;break;}
    }
    if(found==null)throw new IllegalStateException("Missing original UI placement "+parent+"/"+targetFrame+"/"+id);
    PlaceObjectTypeTag p=(PlaceObjectTypeTag)((Tag)found).cloneTag();MATRIX m=new MATRIX(p.getMatrix());m.translateX=0;m.translateY=0;p.setMatrix(m);p.setDepth(1);s=wrap(swf,p);
   } else if(mode.startsWith("warehouse_static_")) {
    // Each page has a distinct dynamic equipment selection. Do not let page2's
    // held defaults destroy page8's original fourth equipment page in memory.
    swf=new SWF(new FileInputStream(args[0]),false);
    renderFrame=Integer.parseInt(mode.split("_")[2])-1;
    for(int child:new int[]{2083,2086,2089,2092,2096,2099,2102,2103,2108,2642,2644,2646,2648,2650,2652,2653,2654,2655,2720,2721,2722,2723,2724,2725,2726,2727,2176,2397,2440,2498,2348})selectedStaticPage(swf,child,1);
    if(renderFrame==3)for(int child:new int[]{2662,2663,2664,2665,2666,2667,2668,2669,2670})selectedStaticPage(swf,child,1);
    if(renderFrame==4)for(int child:new int[]{2682,2687,2690,2691,2692,2693,2694,2695,2696})selectedStaticPage(swf,child,1);
    if(renderFrame==5)for(int child:new int[]{2699,2700,2701,2702,2703,2704,2705,2706})selectedStaticPage(swf,child,1);
    for(int child:new int[]{2349,2401,2444,2502})selectedStaticPage(swf,child,renderFrame==7?4:renderFrame==5 && child==2401?2:1);
    s=(DefineSpriteTag)swf.getCharacter(id);
    for(Tag t:s.getTags().toArrayList())if(t instanceof PlaceObjectTypeTag) {
     int child=((PlaceObjectTypeTag)t).getCharacterId();
     if(swf.getCharacter(child) instanceof DefineEditTextTag || child==2615 || child==2050 || child==2073 || child==2635 || child==2639)s.removeTag(t);
    }
    s.resetTimeline();s.setModified(true);
   } else if(mode.startsWith("screen_static_")) {
    renderFrame=Integer.parseInt(mode.split("_")[2])-1;s=(DefineSpriteTag)swf.getCharacter(id);
    for(Tag t:s.getTags().toArrayList())if(t instanceof PlaceObjectTypeTag) {
     int child=((PlaceObjectTypeTag)t).getCharacterId();CharacterTag tag=swf.getCharacter(child);
     if(tag instanceof DefineButton2Tag || tag instanceof DefineEditTextTag || (id==6956 && (child==1974 || child==1981 || child==1983)))s.removeTag(t);
    }
    s.resetTimeline();s.setModified(true);
   } else if(mode.startsWith("sprite_frame_")) {
    renderFrame=Integer.parseInt(mode.split("_")[2])-1;s=(DefineSpriteTag)swf.getCharacter(id);
    for(Tag t:s.getTags().toArrayList())if(t instanceof PlaceObjectTypeTag) {
     int child=((PlaceObjectTypeTag)t).getCharacterId();
     if(swf.getCharacter(child) instanceof DefineEditTextTag || child==6895 || child==6899 || child==6903)s.removeTag(t);
    }
    s.resetTimeline();s.setModified(true);
   } else if(mode.startsWith("button_")) {
    // Keep the original button renderer's text registration semantics. Turning
    // BUTTONRECORD into ordinary PlaceObject tags shifts embedded DefineText.
    DefineButton2Tag b=(DefineButton2Tag)((DefineButton2Tag)swf.getCharacter(id)).cloneTag();
    b.setCharacterId(swf.getNextCharacterId());
    final SWF buttonSwf=swf;
    b.characters.removeIf(r -> !(mode.startsWith("button_up") ? r.buttonStateUp : mode.startsWith("button_over") ? r.buttonStateOver : r.buttonStateDown)
      || (mode.endsWith("_static") && buttonSwf.getCharacter(r.characterId) instanceof DefineEditTextTag));
    for(BUTTONRECORD r:b.characters) {r.buttonStateUp=true;r.buttonStateOver=false;r.buttonStateDown=false;r.buttonStateHitTest=false;}
    swf.addTag(b);swf.updateCharacters();
    PlaceObject2Tag p=new PlaceObject2Tag(swf);p.setCharacterId(b.getCharacterId());p.setDepth(1);p.setMatrix(new MATRIX());s=wrap(swf,p);
   } else {
    if(mode.equals("grenade_icon")) {
     DefineSpriteTag icon=(DefineSpriteTag)swf.getCharacter(id);
     for(Tag t:icon.getTags().toArrayList())if(t instanceof PlaceObjectTypeTag && ((PlaceObjectTypeTag)t).getDepth()==3)icon.removeTag(t);
     readyFrame(swf,id,false);
    }
    if(mode.equals("panel_ready")) {
     for(int control:new int[]{4054,4056,4060,4064,4066,4068,4070,4072,4074,4076,4078,4081,4083,4088,4092,4103,4110})readyFrame(swf,control,false);
     readyFrame(swf,4391,true);
    }
    PlaceObject2Tag p=new PlaceObject2Tag(swf);p.setCharacterId(id);p.setDepth(1);p.setMatrix(new MATRIX());s=wrap(swf,p);
   }
   swf.clearAllCache();s.resetTimeline();RECT b=s.getTimeline().getDisplayRectWithFilters();
   System.out.printf("UIBOUNDS %s %d %d %d %d%n",key,b.Xmin,b.Ymin,b.Xmax,b.Ymax);
   File out=new File(args[1],key);out.mkdirs();
   new FrameExporter().exportSpriteFrames(null,out.getAbsolutePath(),swf,s.getCharacterId(),Arrays.asList(renderFrame),1,new SpriteExportSettings(SpriteExportMode.PNG,1.0,1),null);
  }
 }
}
'''


def render_ui_frames(directory: Path, specs: dict) -> tuple[dict,dict]:
    helper=directory/"UiRenderer.java";helper.write_text(UI_RENDERER,encoding="utf-8")
    command=["java","-Xmx2g","-Djava.awt.headless=true","-cp",str(FFDEC/"ffdec.jar")+os.pathsep+str(FFDEC/"lib"/"*"),str(helper),str(SWF),str(directory)]
    command += [f"{key}:{value['source_id']}:{value.get('mode','symbol')}" for key,value in specs.items()]
    result=subprocess.run(command,cwd=WORKSPACE,capture_output=True,text=True,encoding="utf-8",errors="replace")
    if result.returncode:raise RuntimeError(result.stdout+result.stderr)
    bounds={};images={}
    for line in result.stdout.splitlines():
        if line.startswith("UIBOUNDS "):
            v=line.split();bounds[v[1]]=list(map(int,v[2:]))
    for key in specs:
        mode=specs[key].get("mode","");frame=int(mode.split("_")[2]) if mode.startswith(("sprite_frame_","screen_static_","warehouse_static_")) else 2 if mode=="panel_crt1_ready" else 3 if mode=="panel_crt2_ready" else 4 if mode=="panel_crt3_ready" else 5 if mode=="panel_crt4_ready" else 1
        paths=list((directory/key).rglob(f"{frame}.png"))
        if len(paths)!=1:raise RuntimeError(f"Expected one selected UI frame for {key}: {paths}")
        images[key]=paths[0]
    return images,bounds


def store_ui_texture(key: str, rendered: Path, bounds: list, definition: dict, previous: dict) -> dict:
    with Image.open(rendered) as image:
        rgba=image.convert("RGBA");rgba.load()
    expected=(math.ceil((bounds[2]-bounds[0])/20),math.ceil((bounds[3]-bounds[1])/20))
    if rgba.size!=expected:raise ValueError(f"UI canvas/bounds mismatch for {key}: {rgba.size} vs {expected}")
    crop=rgba.getchannel("A").getbbox()
    if crop is None:raise ValueError(f"Selected UI resource is empty: {key}")
    out=ASSETS/"ui"/(key+".png");safe_output(out,previous)
    rgba.crop(crop).save(out,compress_level=9)
    return {"path":"res://"+out.relative_to(PROJECT).as_posix(),"region":[0,0,crop[2]-crop[0],crop[3]-crop[1]],
            "pivot":[round(-bounds[0]/20-crop[0],6),round(-bounds[1]/20-crop[1],6)],
            "source_bounds_twips":bounds,"source_canvas_size":list(rgba.size),"union_crop":list(crop),
            "source_frame":1,"conversion":"FFDec in-memory original placement; exact source bounds, one alpha union crop, no recentering or resampling",
            **definition,"output":output_record(out)}

PLAYER_RENDERER = r'''
import java.io.*;
import java.util.*;
import com.jpexs.decompiler.flash.SWF;
import com.jpexs.decompiler.flash.tags.*;
import com.jpexs.decompiler.flash.tags.base.*;
import com.jpexs.decompiler.flash.types.RECT;
import com.jpexs.decompiler.flash.exporters.FrameExporter;
import com.jpexs.decompiler.flash.exporters.settings.SpriteExportSettings;
import com.jpexs.decompiler.flash.exporters.modes.SpriteExportMode;
class PlayerRenderer {
 static void selectPage(SWF swf,int id,int selected) throws Exception {
  DefineSpriteTag s=(DefineSpriteTag)swf.getCharacter(id);List<Tag> tags=new ArrayList<>();int frame=1;
  for(Tag t:s.getTags()) {
   if(t instanceof ShowFrameTag){if(frame++==selected)break;continue;}
   if(t instanceof PlaceObjectTypeTag || t instanceof RemoveObjectTag || t instanceof RemoveObject2Tag)tags.add(t.cloneTag());
  }
  for(Tag t:s.getTags().toArrayList())s.removeTag(t);
  for(Tag t:tags)s.addTag(t);
  s.addTag(new ShowFrameTag(swf));s.setFrameCount(1);s.resetTimeline();s.setModified(true);
 }
 static void omitChildren(SWF swf,int parent,int[] children) throws Exception {
  DefineSpriteTag sprite=(DefineSpriteTag)swf.getCharacter(parent);Map<Integer,Boolean> omitted=new HashMap<>();
  for(Tag t:sprite.getTags().toArrayList()) {
   if(t instanceof PlaceObjectTypeTag) {
    PlaceObjectTypeTag p=(PlaceObjectTypeTag)t;
    if(p.getCharacterId()>0){boolean hide=false;for(int child:children)if(p.getCharacterId()==child)hide=true;omitted.put(p.getDepth(),hide);}
    if(omitted.getOrDefault(p.getDepth(),false))sprite.removeTag(t);
   } else if(t instanceof RemoveObject2Tag) {
    int depth=((RemoveObject2Tag)t).depth;if(omitted.getOrDefault(depth,false))sprite.removeTag(t);omitted.remove(depth);
   }
  }
  sprite.resetTimeline();sprite.setModified(true);
 }
 public static void main(String[] args) throws Exception {
  SWF swf=new SWF(new FileInputStream(args[0]),false);
   int ammoPage=1,crt2Page=0;for(String arg:args){if(arg.startsWith("ammo="))ammoPage=Integer.parseInt(arg.substring(5));if(arg.startsWith("crt2="))crt2Page=Integer.parseInt(arg.substring(5));}
   // ACT04 selectors are applied before the legacy first-page pass. In the
   // original actor path, these body parts select pren+1, not equipment pages.
   if(crt2Page>0) {
    for(int id:new int[]{24,47,56,3632,3679,3774,3786,3808,3815,5545})selectPage(swf,id,crt2Page);
    for(int id:new int[]{23,46,55,3773,3785,3807,3814,3800,5252,5293,5413,5450,5647})selectPage(swf,id,1);
    for(int id:new int[]{5191,5201})selectPage(swf,id,3);
    DefineSpriteTag torso=(DefineSpriteTag)swf.getCharacter(46);
    for(Tag t:torso.getTags().toArrayList())if(t instanceof PlaceObjectTypeTag && Arrays.asList("wing","전펙").contains(((PlaceObjectTypeTag)t).getInstanceName()))torso.removeTag(t);
    torso.resetTimeline();torso.setModified(true);
    omitChildren(swf,5649,new int[]{5416,5417});
    omitChildren(swf,5619,new int[]{5618});
    omitChildren(swf,5618,new int[]{5617});
    omitChildren(swf,5313,new int[]{5289});
    omitChildren(swf,802,new int[]{633});
    omitChildren(swf,685,new int[]{665});
    omitChildren(swf,676,new int[]{665});
   }
  DefineSpriteTag ammo=(DefineSpriteTag)swf.getCharacter(541);PlaceObjectTypeTag selectedAmmo=null;int ammoFrame=1;
  for(Tag t:ammo.getTags()) {
   if(t instanceof ShowFrameTag)ammoFrame++;
   if(ammoFrame==ammoPage && t instanceof PlaceObjectTypeTag && ((PlaceObjectTypeTag)t).getCharacterId()>0)selectedAmmo=(PlaceObjectTypeTag)t;
  }
  if(selectedAmmo==null)throw new IllegalStateException("Missing original ammo541 selected page "+ammoPage);
  Tag ammoPlacement=((Tag)selectedAmmo).cloneTag();
  for(Tag t:ammo.getTags().toArrayList())ammo.removeTag(t);
  ammo.addTag(ammoPlacement);ammo.addTag(new ShowFrameTag(swf));ammo.setFrameCount(1);ammo.resetTimeline();ammo.setModified(true);
  for(int id:new int[]{3572,3588,3597,3602,3610,3620,3631,3632,3641,3650,3659,3674,3678,3679,3688,3694,3725,3761,3763,4543,4632,4634,4765,4776,542,5627}) {
   DefineSpriteTag s=(DefineSpriteTag)swf.getCharacter(id);
   boolean after=false;
   for(Tag t:s.getTags().toArrayList()) {
    boolean hidden=(id==3588 || id==3620) && t instanceof PlaceObjectTypeTag &&
      Arrays.asList("wing","전펙").contains(((PlaceObjectTypeTag)t).getInstanceName());
    if(after || hidden)s.removeTag(t);
    if(t instanceof ShowFrameTag)after=true;
   }
   s.setFrameCount(1);s.resetTimeline();s.setModified(true);
  }
  // Parent5633 keeps its own height/landing timeline. Child5628 has an
  // independent input-driven clock and must never be baked into that atlas.
  DefineSpriteTag jump=(DefineSpriteTag)swf.getCharacter(5633);boolean hiddenAir=false;
  for(Tag t:jump.getTags().toArrayList()) {
   if(t instanceof PlaceObjectTypeTag && ((PlaceObjectTypeTag)t).getDepth()==1) {
    int child=((PlaceObjectTypeTag)t).getCharacterId();
    if(child>0)hiddenAir=(child==5628);
    if(hiddenAir)jump.removeTag(t);
   } else if(t instanceof RemoveObject2Tag && ((RemoveObject2Tag)t).depth==1) {
    if(hiddenAir)jump.removeTag(t);
    hiddenAir=false;
   }
  }
  jump.resetTimeline();jump.setModified(true);
  // CRT1 uses the same independent jump contract with a different air child.
  omitChildren(swf,5636,new int[]{5635});
  omitChildren(swf,4954,new int[]{4935});
  omitChildren(swf,5137,new int[]{5128});
  omitChildren(swf,5141,new int[]{5128});
  omitChildren(swf,5881,new int[]{5854,5879});
  // Q holds its parent at12 while the loading bar4711 independently reaches
  // its empty stop frame19. Keep that child out of the held parent image.
  DefineSpriteTag ammoChoice=(DefineSpriteTag)swf.getCharacter(4718);
  for(Tag t:ammoChoice.getTags().toArrayList()) {
   if(t instanceof PlaceObjectTypeTag && ((PlaceObjectTypeTag)t).getDepth()==63)ammoChoice.removeTag(t);
   else if(t instanceof RemoveObject2Tag && ((RemoveObject2Tag)t).depth==63)ammoChoice.removeTag(t);
  }
  ammoChoice.resetTimeline();ammoChoice.setModified(true);
  // Two Y effects stop on an empty final source frame. FFDec does not execute
  // stop(), so pad only that empty end in the in-memory render copy to cover
  // the reviewed40-frame parent range; never expose padding as game frames.
  for(int id:new int[]{4806,4810}) {
   DefineSpriteTag effect=(DefineSpriteTag)swf.getCharacter(id);
   int count=0;for(Tag t:effect.getTags())if(t instanceof ShowFrameTag)count++;
   while(count<43){effect.addTag(new ShowFrameTag(swf));count++;}
   effect.setFrameCount(count);effect.resetTimeline();effect.setModified(true);
  }
  // The source T parent holds6 while4759 independently loops16 frames.
  DefineSpriteTag sniper=(DefineSpriteTag)swf.getCharacter(4760);
  for(Tag t:sniper.getTags().toArrayList()) {
   if(t instanceof PlaceObjectTypeTag && ((PlaceObjectTypeTag)t).getDepth()==10)sniper.removeTag(t);
   else if(t instanceof RemoveObject2Tag && ((RemoveObject2Tag)t).depth==10)sniper.removeTag(t);
  }
  sniper.resetTimeline();sniper.setModified(true);
  omitChildren(swf,6813,new int[]{6789,6795,6800,6812});
  omitChildren(swf,6795,new int[]{6794});
  // Air pose and hit flash have independent source clocks. Export separately;
  // otherwise the first flash frame is baked permanently into the held pose.
  for(int id:new int[]{4028,7175,7436}) {
   DefineSpriteTag s=(DefineSpriteTag)swf.getCharacter(id);
   for(Tag t:s.getTags().toArrayList()) {
    if(t instanceof PlaceObjectTypeTag && "타격".equals(((PlaceObjectTypeTag)t).getInstanceName()))s.removeTag(t);
   }
   s.resetTimeline();s.setModified(true);
  }
  swf.clearAllCache();
  for(int n=2;n<args.length;n++) {
    if(args[n].startsWith("ammo=") || args[n].startsWith("shot_parent=") || args[n].startsWith("crt2="))continue;
   String[] pieces=args[n].split(":");int id=Integer.parseInt(pieces[0]);
   List<Integer> frames=new ArrayList<>();
   for(String f:pieces[1].split(","))frames.add(Integer.parseInt(f)-1);
   int renderId=id;
    if(id==4689 || id==4698 || id==4923 || id==3887 || id==4580 || id==4589) {
    // This FX is a sibling of the hit body, with a parent glow filter. Clone
    // its exact source placement in an in-memory wrapper so filter and scale
    // are rendered by FFDec; translation remains runtime actor metadata.
     int sourceParent=(id==4580 || id==4589)?4592:6732;
    if(id==3887){sourceParent=3889;for(String arg:args)if(arg.startsWith("shot_parent="))sourceParent=Integer.parseInt(arg.substring(12));}
    DefineSpriteTag parent=(DefineSpriteTag)swf.getCharacter(sourceParent);
    PlaceObjectTypeTag source=null;int parentFrame=1;
     int selectedParent=(id==3887 || id==4580 || id==4589)?9:id==4689?14:id==4698?15:45;
    for(Tag t:parent.getTags()) {
     if(t instanceof ShowFrameTag)parentFrame++;
     if(parentFrame==selectedParent && t instanceof PlaceObjectTypeTag && ((PlaceObjectTypeTag)t).getCharacterId()==id) {
      source=(PlaceObjectTypeTag)t;break;
     }
    }
    if(source==null)throw new IllegalStateException("Missing player source placement "+id+" parent"+selectedParent);
    PlaceObjectTypeTag placement=(PlaceObjectTypeTag)((Tag)source).cloneTag();
    com.jpexs.decompiler.flash.types.MATRIX matrix=new com.jpexs.decompiler.flash.types.MATRIX(placement.getMatrix());
    matrix.translateX=0;matrix.translateY=0;placement.setMatrix(matrix);
    DefineSpriteTag wrapper=new DefineSpriteTag(swf);renderId=swf.getNextCharacterId();
    wrapper.setCharacterId(renderId);wrapper.addTag((Tag)placement);
     int count=id==4580?12:id==4589?14:id==3887?4:id==4689?8:30;
    for(int frame=0;frame<count;frame++)wrapper.addTag(new ShowFrameTag(swf));
    wrapper.setFrameCount(count);swf.addTag(wrapper);swf.updateCharacters();swf.clearAllCache();
   }
   DefineSpriteTag s=(DefineSpriteTag)swf.getCharacter(renderId);s.resetTimeline();
   // Match FrameExporter.MyFrameIterator's exact PNG canvas calculation.
   // Sprite.getRectWithFilters differs after removing an independent nested FX.
   RECT r=s.getRectWithStrokes(),b=s.getTimeline().getDisplayRectWithFilters();
   System.out.printf("BOUNDS %d %d %d %d %d %d %d %d %d%n",id,r.Xmin,r.Ymin,r.Xmax,r.Ymax,b.Xmin,b.Ymin,b.Xmax,b.Ymax);
   File out=new File(args[1],Integer.toString(id));out.mkdirs();
   new FrameExporter().exportSpriteFrames(null,out.getAbsolutePath(),swf,renderId,frames,1,new SpriteExportSettings(SpriteExportMode.PNG,1.0,1),null);
  }
 }
}
'''


def render_default_player_frames(directory: Path, keys: list[str] | None = None, ammo_page: int = 1, crt2_page: int = 0, crt3_page: int = 0, source_setup: str = "") -> tuple[dict, dict]:
    if ammo_page not in (1,2,3):raise ValueError("Only original ammo541 source pages1/2/3 exist")
    directory.mkdir(parents=True,exist_ok=True)
    renderer=PLAYER_RENDERER
    if crt3_page:
        plan=json.loads((PROJECT/"data/act05_crt3_import.json").read_text(encoding="utf-8"))
        setup="\n".join(f"selectPage(swf,{int(i)},{int(page)});"for i,page in plan["selector_pages"].items())
        setup+=f"\nselectPage(swf,74,{crt3_page});\n"
        setup+="\n".join("omitChildren(swf,%d,new int[]{%s});"%(int(i),",".join(map(str,children)))for i,children in plan["independent_children_removed"].items())
        setup+='\nDefineSpriteTag torso3=(DefineSpriteTag)swf.getCharacter(46);for(Tag t:torso3.getTags().toArrayList())if(t instanceof PlaceObjectTypeTag && Arrays.asList("wing","전펙").contains(((PlaceObjectTypeTag)t).getInstanceName()))torso3.removeTag(t);torso3.resetTimeline();torso3.setModified(true);\n'
        for child,stop in plan.get("render_stop_hold",{}).items():
            setup+=f"\n{{DefineSpriteTag hold=(DefineSpriteTag)swf.getCharacter({child});int count=0;boolean after=false;for(Tag t:hold.getTags().toArrayList()){{if(after)hold.removeTag(t);else if(t instanceof ShowFrameTag){{count++;if(count=={stop})after=true;}}}}while(count<148){{hold.addTag(new ShowFrameTag(swf));count++;}}hold.setFrameCount(count);hold.resetTimeline();hold.setModified(true);}}\n"
        renderer=renderer.replace('  swf.clearAllCache();\n  for(int n=2;',setup+'\n  swf.clearAllCache();\n  for(int n=2;',1)
        renderer=renderer.replace('if(id==4689 ||','if(id==6278 || id==4689 ||',1).replace('int sourceParent=(id==4580','int sourceParent=id==6278?6299:(id==4580',1).replace('int selectedParent=(id==3887','int selectedParent=id==6278?1:(id==3887',1).replace('int count=id==4580?12:','int count=id==6278?44:id==4580?12:',1).replace('DefineSpriteTag parent=(DefineSpriteTag)swf.getCharacter(sourceParent);','SWF lookupSwf=id==6278?new SWF(new FileInputStream(args[0]),false):swf;DefineSpriteTag parent=(DefineSpriteTag)lookupSwf.getCharacter(sourceParent);',1)
    if source_setup:
        renderer=renderer.replace('  swf.clearAllCache();\n  for(int n=2;',source_setup+'\n  swf.clearAllCache();\n  for(int n=2;',1)
    helper=directory/"PlayerRenderer.java";helper.write_text(renderer,encoding="utf-8")
    selected={}
    for key,spec in ANIMATIONS.items():
        if keys is not None and key not in keys:continue
        if keys is not None or key in ACT02_ANIMATIONS or key.startswith(("player_", "crt0_", "crt1_", "projectile", "boss7176_", "enemy_air", "air_hit_")):
            selected.setdefault(spec[0],set()).update(spec[1])
    specs={ident:sorted(frames) for ident,frames in selected.items()}
    command=["java","-Xmx2g","-Djava.awt.headless=true","-cp",str(FFDEC/"ffdec.jar")+os.pathsep+str(FFDEC/"lib"/"*"),str(helper),str(SWF),str(directory)]
    command += ["ammo="+str(ammo_page),*[str(i)+":"+",".join(map(str,frames)) for i,frames in specs.items()]]
    if crt2_page:
        if crt2_page not in (1,2):raise ValueError("CRT2 pren selector has only reviewed source pages1/2")
        command.append("crt2="+str(crt2_page))
    if keys is not None and "enemy7437_shot_marker" in keys:
        if "enemy_shot_marker" in keys:raise ValueError("Two source3887 parent-filter variants require separate bounded render calls")
        command.append("shot_parent=7422")
    result=subprocess.run(command,cwd=WORKSPACE,capture_output=True,text=True,encoding="utf-8",errors="replace")
    if result.returncode:raise RuntimeError(result.stdout+result.stderr)
    bounds={}
    for line in result.stdout.splitlines():
        if line.startswith("BOUNDS "):
            v=list(map(int,line.split()[1:]));bounds[v[0]]={"stroke_twips":v[1:5],"filter_twips":v[5:9]}
    folders={}
    for i in specs:
        candidates=[p for p in (directory/str(i)).iterdir() if p.is_dir() and p.name.startswith("DefineSprite_")]
        if len(candidates)!=1:
            raise RuntimeError(f"Expected one rendered folder for source {i}, got {candidates}")
        folders[i]=candidates[0]
    for i,frames in specs.items():
        for f in frames:
            if not (folders[i]/f"{f}.png").exists():
                raise RuntimeError(f"Renderer did not create expected {i}/{f}.png; outputs: {list(folders[i].rglob('*.png'))[:8]}")
    return folders,bounds

def sha256(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()

def flash_bounds(ids: list[int]) -> dict[int, dict]:
    """Use the exact exporter version's bounds, rather than guessing registration."""
    with tempfile.TemporaryDirectory(prefix="leba_swf_bounds_") as tmp:
        helper = Path(tmp) / "Bounds.java"
        helper.write_text(BOUNDS_HELPER, encoding="utf-8")
        classpath = str(FFDEC / "ffdec.jar") + os.pathsep + str(FFDEC / "lib" / "*")
        command = ["java", "-Xmx2g", "-Djava.awt.headless=true", "-cp", classpath, str(helper), str(SWF), *map(str, ids)]
        result = subprocess.run(command, cwd=WORKSPACE, capture_output=True, text=True, encoding="utf-8", errors="replace", check=True)
    output = {}
    for line in result.stdout.splitlines():
        if line.startswith("BOUNDS "):
            v = list(map(int, line.split()[1:]))
            output[v[0]] = {"stroke_twips": v[1:5], "filter_twips": v[5:9]}
    if set(output) != set(ids):
        raise RuntimeError(f"Incomplete FFDec bounds response: {set(ids) - set(output)}")
    return output

# Selections are bounded by the original script routes documented in
# docs/工单01_原作依据.md. Special-equipment branches are deliberately separate.
ANIMATIONS = {
    "player_idle": (4544, list(range(1, 91)), True, [-3.0, 1.5], 6732, 1),
    "player_move": (4617, list(range(1, 11)), True, [6.65, 10.05], 6732, 2),
    "player_basic": (4637, [1, 2, 3, 4, *range(6, 20)], False, [-3.0, 72.45], 6732, 7),
    "player_hit": (4686, list(range(1, 15)), False, [-5.6, 0.2], 6732, 14),
    "player_skill": (4685, list(range(1, 23)), False, [-44.6, 0.85], 6732, 13),
    "enemy_idle": (3898, [1], True, [0.0, -66.25], 4030, 1),
    "enemy_move": (3873, list(range(1, 21)), True, [0.0, -65.9], 4030, 1),
    "enemy_attack": (3898, list(range(5, 51)), False, [0.0, -66.25], 4030, 1),
    "enemy_hit": (3898, list(range(51, 63)), False, [0.0, -66.25], 4030, 1),
    "enemy_death": (3897, list(range(1, 16)), False, [2.9, -53.15], 4030, 1),
    "projectile": (1474, list(range(1, 11)), False, [0.0, 0.0], None, None),
    "crt0_basic2": (4638, list(range(1, 14)), False, [10.35, 0.85], 6732, 8),
    "crt0_basic3": (4639, list(range(1, 27)), False, [10.25, 0.8], 6732, 9),
    "crt0_basic5": (4699, list(range(1, 14)), False, [10.2, 0.75], 6732, 16),
    "crt0_basic6": (4648, list(range(1, 21)), False, [13.9, 0.75], 6732, 10),
    # Preserve control frame5 too; its goto6 scheduling is a runtime question,
    # and must not be dictated by an atlas that lacks the source image.
    "crt0_skill_s": (4668, list(range(1, 18)), False, [14.95, 0.75], 6732, 11),
    "crt1_idle": (4824, list(range(1, 96)), True, [-3.0, 0.85], 6732, 30),
    "crt1_move": (4841, list(range(1, 11)), True, [8.75, 11.0], 6732, 31),
    "crt1_basic": (4860, list(range(1, 19)), False, [-3.3, 70.7], 6732, 37),
    "crt1_hit": (4920, list(range(1, 15)), False, [-4.75, -0.05], 6732, 44),
    "crt1_skill_s": (4917, list(range(1, 18)), False, [13.85, -0.7], 6732, 42),
    "projectile_rising": (1472, list(range(1, 11)), False, [0.0, 0.0], None, None),
    "projectile_strong": (1473, list(range(1, 11)), False, [0.0, 0.0], None, None),
    "boss7176_idle": (7170, [1], True, [0.0, -71.4], 7176, 1),
    "boss7176_move": (7158, list(range(1, 12)), True, [0.0, -71.4], 7176, 1),
    "boss7176_attack": (7170, list(range(6, 46)), False, [0.0, -71.4], 7176, 1),
    "boss7176_ranged": (7170, [*range(46, 91), *range(113, 131)], False, [0.0, -71.4], 7176, 1),
    "boss7176_hit": (7170, list(range(99, 110)), False, [0.0, -71.4], 7176, 1),
    "boss7176_evade": (7168, list(range(1, 81)), False, [-0.3, -71.4], 7176, 1),
    "boss7176_dead": (7169, list(range(1, 11)), False, [0.0, -71.4], 7176, 1),
    "enemy_air": (4028, [1, 2], False, [7.9, -6.65], 4030, 2),
    "boss7176_air": (7175, [1, 2], False, [0.0, -61.0], 7176, 2),
    "air_hit_marker": (3889, list(range(1, 9)), False, [0.0, 0.0], None, None),
    "player_hit_fx": (4689, list(range(1, 9)), False, [0.0, 0.0], 6732, 14),
    "crt0_jump": (5633, list(range(1, 36)), False, [0.35, 78.25], 6732, 95),
    "crt0_jump_air": (5628, list(range(1, 7)), False, [0.0, 0.0], 5633, 15),
    "crt0_down": (4672, list(range(1, 13)), False, [-3.0, 72.45], 6732, 12),
    "projectile_diagonal": (1385, list(range(1, 13)), False, [0.0, 0.0], None, None),
    "crt0_skill_z": (4622, list(range(1, 15)), False, [-3.0, 3.25], 6732, 5),
    "crt0_move_z": (4625, list(range(1, 23)), False, [-45.0, 0.85], 6732, 6),
}

# ACT02 selections are independent source routes, not a claim that a whole
# exported timeline plays straight through. Shared6010 A/W ranges stay separate.
ACT02_ANIMATIONS = {
    "crt0_skill_w": (6010, list(range(1, 11)), False, [4.65, 11.8], 6732, 113),
    "crt0_skill_a": (6010, list(range(21, 31)), False, [4.65, 11.8], 6732, 113),
    "crt0_load_f": (6012, list(range(1, 16)), False, [-9.05, 0.6], 6732, 114),
    "crt0_load_g": (6014, list(range(1, 16)), False, [-9.3, 0.45], 6732, 115),
    "crt0_load_h": (6016, list(range(1, 16)), False, [-9.3, 0.3], 6732, 116),
    "crt0_skill_q": (4718, list(range(1, 31)), False, [-3.0, 0.85], 6732, 18),
    "crt0_q_loading": (4711, list(range(1, 20)), False, [1.8, -83.35], 4718, 1),
    "crt0_runner_wait": (1107, list(range(1,151)), False, [0.0,25.0], 1108, 1),
    "crt0_runner_blast": (1108, list(range(2,18)), False, [0.0,0.0], None, None),
    "summon_mine_right": (613, list(range(1,38)), False, [0.0,0.0], None, None),
    "summon_mine_left": (603, list(range(1,38)), False, [0.0,0.0], None, None),
    "hud_grenade_flash": (6892, list(range(1,11)), False, [0.0,0.0], None, None),
    "crt0_skill_e": (4777, list(range(1,14)), False, [-3.35,1.5], 6732, 21),
    "crt0_detonate": (4779, list(range(1,22)), False, [-3.3,0.55], 6732, 22),
    "crt0_skill_r": (4798, list(range(1,44)), False, [14.95,0.75], 6732, 23),
    "crt0_skill_v": (5678, list(range(1,72)), False, [-3.65,3.8], 6732, 98),
    "crt0_grenade_h": (4744, list(range(1,119)), False, [-3.0,1.35], 6732, 19),
    "crt0_grenade_f": (4744, list(range(119,181)), False, [-3.0,1.35], 6732, 19),
    "crt0_grenade_g": (4744, list(range(181,244)), False, [-3.0,1.35], 6732, 19),
    "crt0_dead": (4823, list(range(1,31)), False, [-1.0,-0.05], 6732, 29),
    "crt1_dead": (5174, list(range(1,31)), False, [-4.15,-1.7], 6732, 62),
    "crt0_skill_y": (4812, list(range(1,41)), False, [-2.95,0.85], 6732, 24),
    "crt0_y_focus": (4813, list(range(1,39)), False, [-2.35,0.85], 6732, 25),
    "crt0_skill_t": (4760, list(range(1,7)), False, [43.4,-0.15], 6732, 20),
    "crt0_t_hold": (4759, list(range(1,17)), True, [3.95,11.65], 4760, 6),
    "sniper_main": (6813, list(range(1,12)), False, [0.0,0.0], None, None),
    "sniper_reticle": (6789, list(range(1,16)), False, [24.0,46.1], 6813, 6),
    "sniper_ammo": (6795, list(range(1,8)), False, [405.5,80.35], 6813, 6),
    "sniper_casing": (6794, list(range(1,19)), False, [0.0,0.0], None, None),
    "sniper_timer": (6812, [1,30,59,88,115,135,155,175,195,215,240], False, [365.0,340.0], 6813, 6),
    "crt0_fire_floor": (1503, list(range(1,31)), True, [182.05,6.3], 1513, 2),
    "crt0_fire_spark": (1504, list(range(1,9)), False, [0.0,0.0], None, None),
    "c4_charge": (3907, list(range(1,11)), True, [0.2,1.0], 3916, 1),
    "c4_charge_glow": (3912, list(range(1,21)), True, [-0.4,0.75], 3916, 1),
    "c4_blink": (3915, [2,3,4], True, [3.25,0.1], 3916, 1),
    "c4_blast": (1138, list(range(1,10)), False, [-18.9,-18.6], 3916, 2),
    "projectile_fire": (1474, list(range(1,12)), False, [0.0,0.0], None, None),
    "projectile_silver": (1474, list(range(1,12)), False, [0.0,0.0], None, None),
    "projectile_strong_fire": (1473, list(range(1,12)), False, [0.0,0.0], None, None),
    "projectile_strong_silver": (1473, list(range(1,12)), False, [0.0,0.0], None, None),
    "projectile_rising_silver": (1472, list(range(1,12)), False, [0.0,0.0], None, None),
    "projectile_diagonal_fire": (1385, list(range(1,13)), False, [0.0,0.0], None, None),
    "projectile_diagonal_silver": (1385, list(range(1,13)), False, [0.0,0.0], None, None),
    "y_normal_1": (4423, list(range(1,100)), True, [90.7,-17.05], 4460, 1),
    "y_normal_2": (4433, list(range(1,47)), True, [2.0,-12.0], 4460, 1),
    "y_normal_3": (4436, list(range(1,43)), True, [58.2,15.15], 4460, 1),
    "y_normal_4": (4459, list(range(1,35)), True, [134.55,-0.2], 4460, 1),
    "y_walk_1": (4461, list(range(1,14)), True, [78.7,-24.4], 4465, 2),
    "y_walk_2": (4462, list(range(1,14)), True, [0.0,-2.7], 4465, 2),
    "y_walk_3": (4463, list(range(1,14)), True, [140.55,-3.2], 4465, 2),
    "y_walk_4": (4464, list(range(1,14)), True, [58.2,13.15], 4465, 2),
    "y_focus_1": (4482, list(range(1,7)), True, [88.7,-16.1], 4486, 1),
    "y_focus_2": (4483, list(range(1,21)), True, [132.55,1.3], 4486, 1),
    "y_focus_3": (4484, list(range(1,27)), True, [0.0,-10.5], 4486, 1),
    "y_focus_4": (4485, list(range(1,6)), True, [56.2,17.35], 4486, 1),
    "y_spawn_fx": (4472, list(range(1,8)), False, [0.0,0.0], None, None),
    "y_exit": (4490, list(range(1,10)), False, [-158.45,-5.35], 4491, 4),
    "y_timer": (4480, [161,187,212,237,262], False, [-63.95,-112.05], 4491, 2),
    "ammo_fire_blast_a": (731, list(range(1,11)), False, [0.0,0.0], None, None),
    "ammo_fire_blast_b": (731, list(range(27,35)), False, [0.0,0.0], None, None),
    "enemy_frozen": (3893, list(range(1,8)), False, [0.0,0.0], 3895, 1),
    "boss7176_frozen": (7166, list(range(1,8)), False, [0.0,0.0], 7167, 1),
    "status_shock": (3928, list(range(2,11)), True, [3.35,-2.6], 4021, 1),
    "status_stun": (3939, list(range(2,11)), True, [-0.6,-64.05], 4021, 1),
    "status_sniper_hit": (3945, list(range(1,8)), False, [6.5,-104.55], 4021, 1),
    "sniper_glass": (728, list(range(1,31)), False, [0.0,0.0], None, None),
    "hud_y_cutin": (6835, list(range(1,34)), False, [-771.15,16.6], 6917, 1),
}
ACT03_ANIMATIONS = {
    "crt1_basic2": (4863, list(range(1,14)), False, [10.3,-.95], 6732, 38),
    "crt1_basic3": (4864, list(range(1,14)), False, [10.3,-1.15], 6732, 39),
    "crt1_basic4": (4865, list(range(1,14)), False, [10.3,-1.05], 6732, 40),
    "crt1_basic5": (4875, list(range(1,21)), False, [13.85,-.7], 6732, 41),
    "crt1_jump": (5636, list(range(1,36)), False, [-.2,78.45], 6732, 96),
    "crt1_jump_air": (5635, list(range(1,7)), False, [0.,0.], None, None),
    "crt1_down": (4919, list(range(1,13)), False, [-4.4,71.9], 6732, 43),
    "crt1_skill_z": (6335, list(range(1,15)), False, [-2.2,1.8], 6732, 144),
    "crt1_move_z": (4858, list(range(1,23)), False, [-46.2,1.1], 6732, 36),
    "crt1_skill_a": (4851, list(range(1,13)), False, [-3.15,.25], 6732, 35),
    "crt1_skill_d": (4928, list(range(1,30)), False, [3.25,-12.5], 6732, 46),
    "crt1_d_follow": (4954, list(range(1,32)), False, [3.6,-8.7], 6732, 47),
    "crt1_skill_f": (5073, list(range(1,16)), False, [6.05,-11.35], 6732, 48),
    "crt1_skill_q": (5075, list(range(1,20)), False, [-4.15,-1.2], 6732, 49),
    "crt1_skill_h": (6338, list(range(1,23)), False, [-4.4,.3], 6732, 145),
    "crt1_h_forward": (5114, list(range(1,24)), False, [3.25,-12.5], 6732, 50),
    "crt1_h_back": (5116, list(range(1,23)), False, [12.1,-15.9], 6732, 51),
    "crt1_h_down": (5122, list(range(1,24)), False, [12.1,-11.1], 6732, 52),
    "crt1_h_up": (5123, list(range(1,23)), False, [12.,-15.65], 6732, 53),
    "crt1_skill_e": (5158, list(range(1,46)), False, [13.4,-9.7], 6732, 55),
    "crt1_skill_r": (5164, list(range(1,11)), False, [3.25,-14.9], 6732, 56),
    "crt1_r_catch1": (5167, list(range(1,36)), False, [4.,-3.2], 6732, 57),
    "crt1_r_catch2": (5170, list(range(1,36)), False, [4.75,-3.2], 6732, 58),
    "crt1_revenger": (5177, list(range(1,22)), False, [5.1,-2.45], 6732, 63),
    "crt1_skill_g": (5889, list(range(1,17)), False, [10.45,-14.8], 6732, 111),
    "crt1_skill_v": (5679, list(range(1,72)), False, [-3.25,3.35], 6732, 99),
    "projectile_head": (1384, list(range(1,11)), False, [0.,0.], None, None),
    "projectile_moving": (618, list(range(1,17)), False, [0.,0.], None, None),
    "crt1_gunhawk1": (6772, list(range(1,47)), False, [0.,0.], None, None),
    "crt1_gunhawk2": (6764, list(range(1,46)), False, [0.,0.], None, None),
    "crt1_gunhawk3": (6753, list(range(1,50)), False, [0.,0.], None, None),
    "crt1_d_air": (4935, list(range(1,6)), False, [0.,0.], None, None),
    "projectile_diagonal_two": (725, list(range(1,13)), False, [0.,0.], None, None),
    "crt1_w_idle": (5137, [1], False, [0.,0.], None, None),
    "crt1_w_move": (5141, list(range(1,18)), True, [0.,0.], None, None),
    "crt1_w_shot": (5128, list(range(1,9)), False, [0.,0.], None, None),
    "crt1_skill_t": (5881, list(range(1,121)), False, [-1.75,-12.5], 6732, 110),
    "crt1_t_hold_body": (5843, [1], False, [0.,0.], None, None),
    "crt1_t_move_body": (5853, list(range(1,17)), True, [0.,0.], None, None),
    "crt1_t_ground_fire": (5845, list(range(1,7)), True, [0.,0.], None, None),
    "crt1_t_ground_shell": (5852, list(range(1,5)), False, [0.,0.], None, None),
    "crt1_t_air_fire1": (5875, list(range(1,8)), True, [0.,0.], None, None),
    "crt1_t_air_fire2": (5876, list(range(1,8)), True, [0.,0.], None, None),
    "crt1_t_air_body": (5877, list(range(1,6)), False, [0.,0.], None, None),
    "crt1_q_buff_edges": (4592, [*range(1,9),*range(401,408)], False, [2.75,-126.3], 6732, 1),
    "crt1_q_buff_ring": (4580, list(range(1,13)), True, [0.,0.], None, None),
    "crt1_q_buff_cloud": (4589, list(range(1,15)), True, [0.,0.], None, None),
    "crt1_q_buff_icon": (4591, [1], True, [0.,0.], None, None),
    "hud_crt1_w_ammo": (6884, list(range(1,23)), False, [1.3,229.4], 6917, 1),
    "hud_crt1_t_cutin": (6835, list(range(34,66)), False, [-771.15,16.6], 6917, 1),
    "enemy7437_idle": (7427, [1], True, [0.,0.], 7437, 1),
    "enemy7437_move": (7382, list(range(1,11)), True, [-6.75,24.], 7427, 2),
    "enemy7437_attack": (7427, [*range(6,30),*range(152,156)], False, [0.,0.], 7437, 1),
    "enemy7437_ranged": (7427, [*range(41,101),*range(30,41)], False, [0.,0.], 7437, 1),
    "enemy7437_melee": (7427, list(range(101,121)), False, [0.,0.], 7437, 1),
    "enemy7437_special": (7427, list(range(121,141)), False, [0.,0.], 7437, 1),
    "enemy7437_hit": (7427, list(range(141,149)), False, [0.,0.], 7437, 1),
    "enemy7437_evade": (7425, list(range(1,36)), False, [-27.3,.8], 7427, 150),
    "enemy7437_dead": (7426, list(range(1,9)), False, [-18.3,-.6], 7427, 151),
    "enemy7437_air": (7436, [1,2], False, [-12.55,.5], 7437, 2),
    "enemy7437_air_hit_marker": (7422, list(range(1,10)), False, [0.,0.], None, None),
    "enemy7437_frozen": (7423, list(range(1,8)), False, [0.,0.], 7424, 1),
    "crt0_knockdown": (4698, list(range(1,31)), False, [3.2,2.05], 6732, 15),
    "crt1_knockdown": (4923, list(range(1,31)), False, [3.3,2.25], 6732, 45),
    "enemy_shot_marker": (3887, list(range(1,5)), False, [119.15,-59.85], 3889, 9),
    "enemy7437_shot_marker": (3887, list(range(1,5)), False, [95.55,-45.1], 7422, 9),
}
ACT03_BAKED_BASIS={"crt0_knockdown":[.857605,-.5115051,.5115051,.857605],"crt1_knockdown":[.86639404,-.49632263,.49632263,.86639404],"enemy7437_shot_marker":[.76223755,0.,0.,.76916504]}
ANIMATIONS.update(ACT02_ANIMATIONS)
ANIMATIONS.update(ACT03_ANIMATIONS)

# ACT04 default CRT2 routes; non-default equipment and locked skills excluded.
ACT04_ANIMATIONS = {
    "crt2_idle": (5179, list(range(1,15)), True, [11.95, 19.6], 6732, 64),
    "crt2_move": (5178, list(range(1,13)), True, [11.95, 19.6], 6732, 65),
    "crt2_basic": (5202, list(range(1,19)), False, [12.0, 20.0], 6732, 69),
    "crt2_basic2": (5204, list(range(1,21)), False, [-28.45, 10.5], 6732, 70),
    "crt2_basic3": (5206, list(range(1,22)), False, [72.0, 0.1], 6732, 71),
    "crt2_skill_z": (5210, list(range(1,18)), False, [8.95, 5.55], 6732, 72),
    "crt2_down": (5211, list(range(1,13)), False, [12.0, 20.0], 6732, 73),
    "crt2_hit": (5212, list(range(1,15)), False, [4.25, 20.0], 6732, 74),
    "crt2_knockdown": (5213, list(range(1,31)), False, [17.15, -1.2], 6732, 75),
    "crt2_skill_a": (5233, list(range(1,51)), False, [12.0, 20.0], 6732, 76),
    "crt2_skill_s_start": (5236, list(range(1,9)), False, [12.0, 20.0], 6732, 77),
    "crt2_skill_s_release": (5257, list(range(1,22)), False, [12.1, 20.35], 6732, 78),
    "crt2_skill_s_full": (5258, list(range(1,27)), False, [12.0, 20.0], 6732, 79),
    "crt2_skill_d": (5313, list(range(1,41)), False, [12.0, 20.0], 6732, 80),
    "crt2_skill_g": (5318, list(range(1,20)), False, [-0.15, 26.2], 6732, 81),
    "crt2_skill_f": (5361, list(range(1,23)), False, [0.0, 26.4], 6732, 82),
    "crt2_skill_h": (5375, list(range(1,21)), False, [11.4, 20.95], 6732, 83),
    "crt2_pren_basic1": (5395, list(range(1,21)), False, [4.65, 20.0], 6732, 84),
    "crt2_pren_basic2": (5418, list(range(1,21)), False, [10.75, 19.6], 6732, 85),
    "crt2_pren_basic3": (5430, list(range(1,21)), False, [1.55, 9.85], 6732, 86),
    "crt2_pren_basic4": (5431, list(range(1,23)), False, [-0.2, -10.85], 6732, 87),
    "crt2_skill_w": (5469, list(range(1,129)), False, [12.25, 21.6], 6732, 88),
    "crt2_skill_e": (5520, [*range(1,31),*range(35,83),*range(90,103)], False, [-54.15, 20.0], 6732, 89),
    "crt2_skill_r": (5619, list(range(1,139)), False, [0.0, 26.0], 6732, 90),
    "crt2_fallen": (5624, list(range(1,7)), False, [-5.6, 49.55], 6732, 93),
    "crt2_dead": (5626, list(range(1,26)), False, [12.0, 20.0], 6732, 94),
    "crt2_jump": (5649, [*range(1,31),*range(57,68)], False, [-0.25, 26.1], 6732, 97),
    "crt2_skill_v": (5752, list(range(1,80)), False, [-11.25, 1.45], 6732, 100),
    "crt2_skill_q": (6007, list(range(1,56)), False, [10.6, 20.05], 6732, 112),
    "crt2_jump_attack_right": (5416, list(range(1,14)), False, [0.,0.], None, None),
    "crt2_r_air": (5618, list(range(1,8)), True, [0.,0.], None, None),
}
ACT04_PREN_VARIANTS = {key:key+"_pren" for key in ACT04_ANIMATIONS if not key.startswith("crt2_pren_") and key!="crt2_r_air"}
ACT04_ANIMATIONS.update({variant:ACT04_ANIMATIONS[key] for key,variant in ACT04_PREN_VARIANTS.items()})
ACT04_COMPONENT_ANIMATIONS={
    "crt2_r_air_back":(5601,[1],True,[0.,0.],None,None),
    "crt2_r_air_hit":(5609,list(range(1,7)),True,[0.,0.],None,None),
    "crt2_r_air_front":(5616,list(range(1,7)),True,[0.,0.],None,None),
    "enemy_bleed":(4000,list(range(1,13)),True,[0.,0.],None,None),
    "crt2_hit_slash_left":(1481,list(range(1,8)),False,[0.,0.],None,None),
    "crt2_hit_slash_horizontal":(1489,list(range(1,8)),False,[0.,0.],None,None),
    "crt2_hit_slash_right":(1496,list(range(1,8)),False,[0.,0.],None,None),
    "crt2_d_blood":(5289,list(range(21,41)),False,[0.,0.],None,None),
    "crt2_f_charge":(802,list(range(1,37)),False,[0.,0.],None,None),
    "crt2_f_charge_core":(633,list(range(1,24)),False,[0.,0.],None,None),
    "crt2_f_burst":(1076,list(range(1,22)),False,[0.,0.],None,None),
    "crt2_air_z_right":(574,list(range(1,7)),False,[0.,0.],None,None),
    "crt2_air_z_left":(971,list(range(1,7)),False,[0.,0.],None,None),
    "crt2_e_right":(685,list(range(1,21)),False,[0.,0.],None,None),
    "crt2_e_left":(676,list(range(1,21)),False,[0.,0.],None,None),
    "crt2_e_charge":(665,list(range(1,10)),False,[0.,0.],None,None),
    "crt2_q_dust_right":(1023,list(range(1,8)),False,[0.,0.],None,None),
    "crt2_q_dust_left":(593,list(range(1,8)),False,[0.,0.],None,None),
    "crt2_h_aura":(4599,list(range(1,36)),True,[0.,0.],None,None),
    "crt2_g_timer":(4601,[*range(1,10),*range(400,408)],False,[0.,0.],None,None),
    "crt2_lust_timer":(4604,[*range(1,10),*range(289,297)],False,[0.,0.],None,None),
    "hud_crt2_r_cutin":(6835,list(range(66,98)),False,[-771.15,16.6],6917,1),
}
ACT04_ANIMATIONS.update(ACT04_COMPONENT_ANIMATIONS)
ANIMATIONS.update(ACT04_ANIMATIONS)
ACT04_PREN_SELECTORS=[24,47,56,3632,3679,3774,3786,3808,3815,5545]
ACT04_STATIC_SELECTORS={23:1,46:1,55:1,3773:1,3785:1,3807:1,3814:1,3800:1,5191:3,5201:3,5252:1,5293:1,5413:1,5450:1,5647:1}

AMMO_VARIANTS={key:3 if key.endswith("_fire") else 2 for key in ACT02_ANIMATIONS if key.startswith("projectile_")}
ACT02_OUTER_OFFSETS = {"crt0_q_loading": [-3.0, 0.85],"crt0_t_hold":[43.4,-0.15]}
FRAME_TRIM_KEYS = set(ACT04_ANIMATIONS) | {"crt0_grenade_h","crt0_grenade_f","crt0_grenade_g","sniper_main","sniper_reticle","hud_y_cutin","hud_crt1_t_cutin","crt1_skill_t","crt1_gunhawk1","crt1_gunhawk2","crt1_gunhawk3"}

PARENT_SCALES = {"crt1_skill_s": [1.000412, 1.0],"sniper_ammo":[0.8200531,1.0],
                 "crt0_fire_floor":[.43778992,.5554352],"c4_charge":[.69821167,.7480316],
                 "c4_charge_glow":[.1296997,.25834656],"c4_blast":[.60580444,.6320801]}
PARENT_SCALES.update({"crt1_basic3":[1.0003967,1.],"crt1_basic4":[1.0003967,1.],"crt1_basic5":[1.000412,1.]})
PARENT_SCALES["crt1_q_buff_edges"]=[1.654419,1.8181763]
ATLAS_DRAW_CONTRACT={"pixel_space":"Unscaled selected source sprite local pixels; immediate-parent translation is encoded into pivot, not applied by moving the sprite node.",
    "formula":"Let q=source local point, B=diag(animation.parent_scale), t=animation.parent_offset_px. pivot=-bounds_min/20-crop_origin-B^-1*t. SourceSprite._draw outputs B*(pixel-pivot)=B*q+t.",
    "source_sprite_position":[0,0],"source_sprite_scale":[1,1],"basis_application":"SourceSprite._draw already multiplies parent_scale. Do not also set Node2D.scale to the immediate-parent B or add t to Node2D.position.",
    "ancestor_rule":"An ancestor container applies only the remaining source transforms above this already encoded immediate parent. For C4 apply enemy→3917→each3916 container; its individual part SourceSprite stays position0/scale1. For floor apply only the root1513 transform;1503 B/t are already handled by draw+pivot.",
    "exception":"Explicit standalone parts with parent=None and offset[0,0], such as fire_spark, require their full instance matrix on an external container."}
NESTED_PLACEMENTS = {
    "boss7176_move": {"parent_id":7170,"parent_frame":2,"child_id":7158,"depth":1,"translate_twips":[0,0]},
    "boss7176_evade": {"parent_id":7170,"parent_frame":111,"child_id":7168,"depth":1,"translate_twips":[-6,0]},
    "boss7176_dead": {"parent_id":7170,"parent_frame":112,"child_id":7169,"depth":1,"translate_twips":[0,0]},
}

# Keep generated filenames stable when the runtime-facing keys become clearer.
TEXTURE_NAMES = {"player_idle":"crt0_idle", "player_move":"crt0_move",
                 "player_basic":"crt0_attack", "player_hit":"crt0_hit",
                 "player_skill":"crt0_skill_d", "projectile":"bullet",
                 "crt0_runner_wait":"summon_runner_wait", "crt0_runner_blast":"summon_runner_blast"}

def sprite_dir(ident: int) -> Path:
    candidates = [p for p in (SOURCES / "sprites").glob(f"DefineSprite_{ident}*")
                  if p.name == f"DefineSprite_{ident}" or p.name.startswith(f"DefineSprite_{ident}_")]
    if len(candidates) != 1:
        raise FileNotFoundError(f"Expected exactly one sprite source for {ident}, got {candidates}")
    return candidates[0]

def source_record(path: Path, ident=None, frame=None) -> dict:
    return {"path": path.relative_to(WORKSPACE).as_posix(), "sha256": sha256(path),
            "bytes": path.stat().st_size, "character_id": ident, "frame": frame}

def output_record(path: Path) -> dict:
    return {"path": path.relative_to(PROJECT).as_posix(), "sha256": sha256(path), "bytes": path.stat().st_size}

def safe_output(path: Path, previous: dict) -> None:
    if not path.resolve().is_relative_to(ASSETS.resolve()):
        raise ValueError(f"Output outside runtime assets: {path}")
    if path.exists():
        key = path.relative_to(PROJECT).as_posix()
        if key not in previous or previous[key] != sha256(path):
            raise FileExistsError(f"Output has unrecorded/local changes, refusing overwrite: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)

def build_animation(key, spec, bounds, previous, provenance, rendered_folder=None, source_frame_map=None, allow_empty=False):
    ident, sequence, loop, offset, parent, parent_frame = spec
    directory = sprite_dir(ident)
    frames, source_rows, union = [], [], None
    size = None
    for number in sequence:
        source_number = (source_frame_map or {}).get(number,number)
        path = directory / f"{source_number}.png"
        if not path.is_file():
            raise FileNotFoundError(f"Animation {key}, ID {ident}, source frame {number}: {path}")
        rendered_path=(rendered_folder/f"{number}.png") if rendered_folder else path
        with Image.open(rendered_path) as original:
            frame = original.convert("RGBA")
            frame.load()
        if size is not None and frame.size != size:
            raise ValueError(f"Canvas size varies within source sprite {ident}: {frame.size} != {size}")
        size = frame.size
        box = frame.getchannel("A").getbbox()
        if box:
            union = box if union is None else (min(union[0],box[0]),min(union[1],box[1]),max(union[2],box[2]),max(union[3],box[3]))
        frames.append(frame)
        source_rows.append(source_record(path, ident, source_number))
    if union is None:
        if not allow_empty and key not in {"crt3_backstep"}:raise ValueError(f"All selected frames are transparent: {key}")
        union=(0,0,1,1) # Reviewed source6158 base excludes its independently timed6156/6157.
    rect = bounds[ident]["filter_twips"]
    expected_size = (math.ceil((rect[2]-rect[0])/20),math.ceil((rect[3]-rect[1])/20))
    if size != expected_size:
        raise ValueError(f"Exporter geometry/canvas mismatch for {key}: image {size}, bounds {expected_size}")
    per_frame_trim=key in FRAME_TRIM_KEYS
    crops=[frame.getchannel("A").getbbox() or (0,0,1,1) for frame in frames] if per_frame_trim else [union]*len(frames)
    width=max(crop[2]-crop[0]for crop in crops);height=max(crop[3]-crop[1]for crop in crops)
    pad=2;cell_w=width+pad*2;cell_h=height+pad*2
    placements=[]
    if per_frame_trim:
        # Variable source bounds vary greatly across a grenade branch or a
        # sniper flash. Shelf-pack trimmed rectangles; pivots still preserve
        # their original registration, never the packed cell's visual centre.
        sx=sy=row_height=atlas_width=0
        for crop in crops:
            w=crop[2]-crop[0]+pad*2;h=crop[3]-crop[1]+pad*2
            if w>4096:raise ValueError(f"Individual selected frame exceeds4096px: {key}")
            if sx+w>4096:sx=0;sy+=row_height;row_height=0
            placements.append((sx+pad,sy+pad));sx+=w;row_height=max(row_height,h);atlas_width=max(atlas_width,sx)
        atlas_size=(atlas_width,sy+row_height)
    else:
        cols=min(len(frames),max(1,int(math.ceil(math.sqrt(len(frames)*cell_h/cell_w)))),4096//cell_w)
        rows=math.ceil(len(frames)/cols)
        if rows*cell_h>4096:
            cols=min(len(frames),4096//cell_w);rows=math.ceil(len(frames)/cols)
        placements=[((i%cols)*cell_w+pad,(i//cols)*cell_h+pad)for i in range(len(frames))]
        atlas_size=(cols*cell_w,rows*cell_h)
    if atlas_size[1]>8192:raise ValueError(f"Selected atlas too large: {key}")
    atlas=Image.new("RGBA",atlas_size,(0,0,0,0))
    parent_scale = PARENT_SCALES.get(key, [1.0, 1.0])
    descriptors=[]
    for i,(number,frame,crop) in enumerate(zip(sequence,frames,crops)):
        x,y=placements[i]
        pivot=[round(-rect[0]/20-crop[0]-offset[0]/parent_scale[0],6),round(-rect[1]/20-crop[1]-offset[1]/parent_scale[1],6)]
        atlas.paste(frame.crop(crop),(x,y))
        alpha=frame.getchannel("A").getbbox()
        alpha_bounds=([round((alpha[0]-crop[0]-pivot[0])*parent_scale[0],6),round((alpha[1]-crop[1]-pivot[1])*parent_scale[1],6),round((alpha[2]-alpha[0])*parent_scale[0],6),round((alpha[3]-alpha[1])*parent_scale[1],6)] if alpha else [0,0,0,0])
        descriptors.append({"region":[x,y,crop[2]-crop[0],crop[3]-crop[1]],"pivot":pivot,"source_frame":number,
                            "alpha_bounds":alpha_bounds,**({"source_crop":list(crop)}if per_frame_trim else {})})
    out=ASSETS/"atlases"/(TEXTURE_NAMES.get(key,key)+".png")
    safe_output(out,previous);atlas.save(out,compress_level=9)
    provenance.extend(source_rows)
    return {"texture":"res://"+out.relative_to(PROJECT).as_posix(),"fps":25,"loop":loop,
            "frames":descriptors,"source_sprite_id":ident,"source_parent_id":parent,"source_parent_frame":parent_frame,
            "source_frame_sequence":sequence,"source_canvas_size":list(size),"union_crop":list(union),
            "source_bounds":bounds[ident],"parent_offset_px":offset,"parent_scale":parent_scale,"padding":pad,
            "nested_placement":NESTED_PLACEMENTS.get(key),
            "anchor_status":"FFDec 26.2.1 Timeline.getDisplayRectWithFilters for derived renders (FrameExporter PNG canvas), source getRectWithFilters for existing exports, and XML placement; no per-frame recentering",
            "conversion":"RGBA, per-frame alpha crop with exact source registration retained in each pivot, no resampling, 2px transparent gutters" if per_frame_trim else "RGBA, one union crop over the selected sequence, no resampling, 2px transparent atlas gutters",
            "render_profile":("crt0_jump_base" if key=="crt0_jump" else "player_hit_fx" if key=="player_hit_fx" else "air_pose_only" if key in ("enemy_air","boss7176_air") else "air_hit_marker" if key=="air_hit_marker" else "projectile_default" if key.startswith("projectile") else "boss7176_source" if key.startswith("boss7176_") else "crt1_default_equipment" if key.startswith("crt1_") else "crt0_default_equipment") if rendered_folder else "original_extracted_png",
            "rendered_frames_sha256":{str(f):sha256(rendered_folder/f"{f}.png") for f in sequence} if rendered_folder else {},
            "output":output_record(out)}

def copy_asset(source, relative_output, previous, provenance, ident=None):
    path=SOURCES/source
    if not path.is_file():raise FileNotFoundError(path)
    if ident==6089 and path.suffix.lower()==".mp3":
        # Original DefineSound6089 has9 complete MPEG frames (10368 samples)
        # followed by non-MPEG trailing bytes. Godot's MP3 importer rejects the
        # whole file; FFmpeg decodes all declared samples into a derived WAV.
        import wave
        out=ASSETS/relative_output.with_suffix(".wav");safe_output(out,previous)
        command=["ffmpeg","-nostdin","-y","-v","error","-i",str(path),"-c:a","pcm_s16le","-map_metadata","-1",str(out)]
        result=subprocess.run(command,capture_output=True,text=True,encoding="utf-8",errors="replace",check=True)
        with wave.open(str(out),"rb")as decoded:
            info={"sample_rate":decoded.getframerate(),"channels":decoded.getnchannels(),"samples":decoded.getnframes(),"sample_bytes":decoded.getsampwidth()}
        if info!={"sample_rate":44100,"channels":2,"samples":10368,"sample_bytes":2}:raise ValueError(f"6089 decoded sample count differs from original DefineSound: {info}")
        record=source_record(path,ident);provenance.append(record)
        return {"path":"res://"+out.relative_to(PROJECT).as_posix(),"source":record,"conversion":"FFmpeg MP3 decode to PCM S16LE WAV; original trailing non-MPEG bytes excluded, all10368 original declared samples retained; source unchanged","decode":info,"decoder_diagnostic":result.stderr.strip(),"output":output_record(out)}
    out=ASSETS/relative_output;safe_output(out,previous);shutil.copy2(path,out)
    record=source_record(path,ident);provenance.append(record)
    return {"path":"res://"+out.relative_to(PROJECT).as_posix(),"source":record,"conversion":"byte-identical copy","output":output_record(out)}

def m1_geometry() -> dict:
    """Selected XML matrices and AS control facts, never image-derived hitboxes."""
    ground_rect=[-28.2,-67.05,65.8,141.0]
    air_xy=[(132,-4441),(132,-4432),(132,-4403),(131,-4357),(130,-4291),(130,-4207),
            (128,-4104),(127,-3982),(126,-3841),(124,-3682),(122,-3504),(120,-3307),
            (118,-3091),(115,-2857),(113,-2604),(110,-2332)]
    overlays={str(f):{"source_sprite_id":5628,"child_offset_px":[x/20,y/20],
                      "offset_px":[round(.35+x/20,6),round(78.25+y/20,6)],
                      "scale":[1.0,1.0],"named_instance":f<30,"input_enabled":f<30,
                      "instance_created_on_parent_frame":15 if f<30 else 30}
              for f,(x,y) in enumerate(air_xy,15)}
    overlays["35"]={"source_sprite_id":5628,"child_offset_px":[5.0,-74.4],"offset_px":[5.35,3.85],
                    "scale":[1.,1.],"named_instance":False,"input_enabled":False,
                    "instance_created_on_parent_frame":35,"terminal_control_frame":True}
    def body_track(ident, parent_frame, count, active, translation):
        return {"source_id":ident,"parent_id":6732,"parent_frame":parent_frame,
                "placement_twips":translation,"stop_source_frame":count,
                "active_source_frames":active,
                "frames_by_body_frame":{str(f):{"shape_id":4545 if f in active else None,
                    "rect":ground_rect.copy() if f in active else [],"empty":f not in active} for f in range(1,count+1)},
                "space":"actor6732; apply root scale/flip only; independent from visible jump height",
                "evidence":"Actual XML PlaceObject/RemoveObject/ShowFrame display list, not PNG alpha; final source frame stops and retains its shape."}
    diagonal=[]
    for f,(x,y) in enumerate(zip([2762,3208,3654,4099,4545,4991,5437,5882,6328,6774],
                                 [-1804,-1603,-1401,-1200,-998,-797,-595,-394,-192,9]),1):
        a,b,c,d=(1.1130371,.5029144,-.67071533,1.4844055) if f in (1,10) else (1.1118011,.50198364,-.66947937,1.4827576)
        diagonal.append({"source_frame":f,"matrix":[a,b,c,d,x/20,y/20],"translate_twips":[x,y]})
    return {
        "player_gravity_body":{
            "source_id":4546,"source_shape_id":4545,"source_frame":1,"instance_name":"중력몸빵",
            "rect":[-28.2,-67.05,65.8,141.0],"space":"actor6732; then actor root scale/flip",
            "source_clip_bounds_twips":[-658,-2790,658,30],
            "shape_placement_twips":[0,-1380],"parent_placement_twips":[94,1449],
            "parent_source_frames":[1,5,6,95],"parent_depth_by_frame":{"1":143,"5":143,"6":143,"95":1017},
            "parent_matrix":[1,0,0,1,4.7,72.45],"persistent_single_frame":True,
            "evidence":"XML actual display lists of sprite6732 frames1/5/6/95; FFDec4546/4547 clip bounds [-658,-2790,658,30].",
            "note":"4546 always retains its shape in these parent states. Default4547 frame1 has identical geometry but frame2 removes it. Jump4745 and Down4673 own blank-frame clocks; parent5 removes hurt body only, parent6 moves hurt body only. Never derive this rect from current hurt visibility or dynamic hurt-body x."},
        "stage_wall":{
            "root_2":{"instance_present":False,"source_id":None,"polygons":[],"geometry_state":"no_named_wall_in_root_display_list"},
            "root_4":{"instance_present":True,"source_id":7131,"depth":1,"source_frame":1,"placement_twips":[5378,4233],"matrix":[1,0,0,1,268.9,211.65],"alpha_mult":0,"polygons":[],"geometry_state":"empty_single_frame_sprite_without_placed_shapes"},
            "root_6":{"instance_present":True,"source_id":7131,"depth":1,"source_frame":1,"placement_twips":[5378,4233],"matrix":[1,0,0,1,268.9,211.65],"alpha_mult":0,"polygons":[],"geometry_state":"empty_single_frame_sprite_without_placed_shapes"},
            "source_point_test":"wall.hitTest(move.xMax,actor.y,true), move.xMin, gravity.xMax, gravity.xMin, in order; corresponding root-x corrections -10,+10,-10,+10",
            "note":"7131 consists only of SoundStreamHead2 and ShowFrame; FFDec clip bounds are all0. No wall drawing/assignment/attach was found in extracted AS. Empty/missing wall is not a filled rectangle, and does not prove a general35..520 clamp. Runtime point-test/boundary behavior still needs original-host observation."},
        "stage_actor_bounds":{
            "source_id":3829,"instance_name":"방도","depth":4703,"placed_root_frame":1,
            "persists_in_root_frames":[2,4,6],"default_pren_by_root_frame":{"2":0,"4":0,"6":0},
            "source":"res/scripts/frame_1/PlaceObject2_3829_4703/CLIPACTIONRECORD onClipEvent(enterFrame)_2.as",
            "condition":"_root.pren == 0 || _root.pren == 1",
            "player_root_x":[0,550],"named_enemy_root_x":[0,550],
            "named_enemies":["적","적2","적3","적4","적5"],
            "else_player_root_x":None,"else_named_enemy_root_x":[-100,650],
            "space":"root stage coordinates, no actor width/margin deduction",
            "tick_phase":"root3829 enterFrame callback; relative ordering with actor callbacks is not dynamically verified",
            "hurt_body_additional_clamp":{"parent_frames":[14,44],"source_id":4547,
                "x":"body._width / 2 .. 550 - body._width / 2",
                "y":"body._width / 2 .. 400 - body._width / 2",
                "source":"res/scripts/DefineSprite_6732/frame_14/PlaceObject2_4547_145/CLIPACTIONRECORD onClipEvent(enterFrame).as and enterFrame_2; frame44 PlaceObject2_4547_572 equivalents"},
            "evidence":"Actual root display list retains root1 placement3829 and original clip actions unchanged at2/4/6; their DoAction scripts each initialize pren=0. Separate from empty wall7131. No Stage.width/height global actor clamp found in extracted AS."},
        "crt0_jump":{
            "source_id":5633,"parent_id":6732,"parent_frame":95,"parent_instance":"동작",
            "parent_offset_px":[.35,78.25],"parent_stop":True,"return_source_frame":35,"return_parent_frame":1,
            "source_facing":1,"air_animation":"crt0_jump_air","air_instance":"점프중",
            "air_overlay_by_frame":overlays,
            "rise_child":{"source_id":5627,"stop_source_frame":1,"parent_frames":list(range(4,15)),
                          "x_twips":-13,"y_twips":[-1346,-1916,-2426,-2877,-3267,-3597,-3867,-4077,-4227,-4317,-4347]},
            "body_track":body_track(4745,95,26,[1,2,3,4,5,6,26],[94,69]),
            "root_move":{"helper_source_id":4937,"helper_placed_at":4,"helper_replaced_at":35,
                         "condition":"named child 점프중._currentframe == 1",
                         "ordered_keys":[{"key":39,"dx":4,"facing":1},{"key":37,"dx":-4,"facing":-1}],
                         "shooting_condition":"active child5628 currentframe != 1",
                         "shooting_order":["x -= 3*bug1","if left: bug1==1 => x-=9*bug1; bug1==-1 => x+=3*bug1","if right: bug1==1 => x+=3*bug1; bug1==-1 => x-=9*bug1"],
                         "root_y_delta":0,"source":"res/scripts/DefineSprite_5633/frame_4/PlaceObject2_4937_93/CLIPACTIONRECORD onClipEvent(enterFrame).as"},
            "air_shot":{"source":"res/scripts/DefineSprite_5633/frame_15/PlaceObject2_5628_1/CLIPACTIONRECORD onClipEvent(enterFrame).as",
                        "input":"enterFrame held Key.isDown(88), after move/fire checks; child1 or6 => gotoAndPlay2",
                        "stop_child_frames":[1,6],"shoot_child_frames":[2,3],"projectile":"projectile_diagonal",
                        "projectile_parent":"actor6732","projectile_x":0,"projectile_y":"220 + child5628._y",
                        "projectile_y_ignores_jump_parent_offset":True,"depth_counter_initial":1,
                        "note":"Default branch does not stop parent5633; equipment timer/air ammo extension not implemented."}},
        "crt0_down":{
            "source_id":4672,"parent_id":6732,"parent_frame":12,"parent_instance":"이동",
            "parent_offset_px":[-3,72.45],"root_dx_per_enter_frame":-5,"multiply_by_facing":True,
            "move_condition":"child_currentframe <= 11","terminal_source_frame":12,
            "terminal_root_dx":-3,"return_parent_frame":1,
            "body_track":body_track(4673,12,10,[10],[94,1449]),
            "visual_nested_id":4671,"visual_nested_y_twips":[-86,-214,-287,-360,-433,-506,-495,-461,-404,-325,-223],
            "visual_nested_x_twips":[70,70,70,70,70,70,68,62,52,39,21],
            "evidence":"parent12 placement enterFrame moves actor; child4672 frame12 adds this._x*bug1 then returns. Body4673 has no shape on1..9; shape4545 placed at10 with y=-1380twips."},
        "projectile_diagonal":{
            "source_id":1385,"source_child_id":542,"default_child_frame":1,
            "rect":[-7.5,-6.3,14.85,12.65],"space":"sprite542 before frame matrix",
            "source_bounds_twips":[-150,-126,147,127],"timeline_matrices":diagonal,
            "matrix_convention":"[a,b,c,d,tx_px,ty_px]; x=a*x+c*y+tx; y=b*x+d*y+ty; then actor root transform",
            "active_source_frames":list(range(1,11)),"empty_stop_source_frame":11,"remove_source_frame":12,
            "landing_check":"542 enterFrame: actor parent95/96 and child5633 frame35 => enclosing projectile gotoAndStop12",
            "normal_hit":{"gravity":-3,"gravity_acceleration_add":.1,"marker_seek":2,"direct_damage":None,
                          "deduplication":"one hita flag per enemy per projectile instance (up to5)"},
            "note":"11 stops after removing visible/hit child, but does not remove empty container. 12 stop/removeMovieClip. Default bullet source541/542 held1; no damage inferred from name."},
        "crt0_skill_z":{
            "source_id":4622,"parent_frame":5,"initial_parent_offset_px":[-3,3.25],
            "dynamic_child_x":"x += (10-x)/2 each parent placement enterFrame",
            "runtime_visual_delta":"current_child_x - initial_parent_offset_px[0]; initial offset already in atlas pivot",
            "terminal_source_frame":14,"terminal_root_dx":"current_child_x * bug1","return_parent_frame":1,
            "hit_helper":{"source_id":1234,"active_source_frames":[6,7,8],"source_rect":[-46.25,-48.3,92.5,96.55],
                          "matrix":[1.2986298,0,0,1.7942505,57.05,-38.25],"space":"child4622 before its dynamic parent offset"},
            "body_present":False,"note":"Parent5 removes body4547 but keeps gravity_body4546. No fixed damage is inferred from helper."},
        "crt0_move_z":{
            "source_id":4625,"parent_frame":6,"initial_parent_offset_px":[-45,.85],
            "terminal_source_frame":22,"return_parent_frame":1,
            "hit_helper":{"source_id":439,"active_source_frames":[7,8,9,10],"source_rect":[-102.4,-57.2,198.3,217.65],
                          "matrix":[.4582672,0,0,.35092163,158.4,28.15],"space":"child4625 before parent offset"},
            "body_dynamic_x":"parent body4547 x += (180-x)/6, initial4.7px; do not treat as fixed ground rect",
            "note":"Movement and input competition belong to runtime source callbacks; not baked into atlas."}
    }


def build_catalog():
    if sha256(SWF) != EXPECTED_SWF_SHA256:
        raise ValueError("The original SWF differs from the investigated version; re-check timeline selections and matrices before importing.")
    previous={};old={}
    if CATALOG.exists():
        old=json.loads(CATALOG.read_text(encoding="utf-8"))
        previous={v["path"]:v["sha256"] for v in old.get("outputs",[])}
    ids=sorted({v[0] for v in ANIMATIONS.values()}|{3856,1119,4546,4547,4684,3875})
    bounds=flash_bounds(ids)
    evidence=[SWF,SOURCES/"structure/game.xml",FFDEC/"ffdec.jar",
              SOURCES/"scripts/DefineSprite_3841/frame_1/DoAction.as",
              SOURCES/"scripts/frame_2/DoAction.as",SOURCES/"scripts/frame_4/DoAction.as"]
    evidence += [SOURCES/f"scripts/DefineSprite_{i}/frame_1/DoAction.as" for i in FROZEN_SELECTORS+[541,542,5627]]
    # Record selected action logic too, including per-frame input/collision events.
    for spec in ANIMATIONS.values():
        ident, sequence, _, _, parent, parent_frame = spec
        roots = list((SOURCES/"scripts").glob(f"DefineSprite_{ident}")) + list((SOURCES/"scripts").glob(f"DefineSprite_{ident}_*"))
        for root in roots:
            for number in sequence:
                evidence.extend((root/f"frame_{number}").rglob("*.as"))
        if parent is not None:
            evidence.extend((SOURCES/f"scripts/DefineSprite_{parent}/frame_{parent_frame}").rglob("*.as"))
    for ident in (4066,4123,4673,4745,5630,1234,439,4064):
        evidence.extend((SOURCES/f"scripts/DefineSprite_{ident}").rglob("*.as"))
    provenance=[source_record(p) for p in evidence]
    with tempfile.TemporaryDirectory(prefix="leba_runtime_render_") as temp:
        rendered_folders,rendered_bounds=render_default_player_frames(Path(temp))
        runtime_bounds={**bounds,**rendered_bounds}
        profiles={1:(rendered_folders,runtime_bounds)}
        for page in (2,3):
            profile_keys=[key for key,value in AMMO_VARIANTS.items()if value==page]
            profiles[page]=render_default_player_frames(Path(temp)/f"ammo_{page}",profile_keys,page)
        animations={}
        for key,spec in ANIMATIONS.items():
            folders,profile_bounds=profiles[AMMO_VARIANTS.get(key,1)]
            animations[key]=build_animation(key,spec,profile_bounds if spec[0] in folders else bounds,previous,provenance,folders.get(spec[0]))
    # This is an independently placed map sprite, never a root timeline screenshot.
    forest=build_animation("forest",(3856,[1],False,[0.,0.],None,None),bounds,previous,provenance)
    textures={"forest":{"path":forest["texture"],"region":forest["frames"][0]["region"],
                        "pivot":forest["frames"][0]["pivot"],"source_sprite_id":3856,
                        "stage_position":[279.35,311.2],"stage_scale":[1.,1.],"output":forest["output"],
                        "source_bounds":bounds[3856],"union_crop":forest["union_crop"]}}
    title_path=SOURCES/"frames"/"1.png"
    with Image.open(title_path) as image:
        title=image.convert("RGBA").crop((0,0,550,265))
    out=ASSETS/"ui"/"title.png";safe_output(out,previous);title.save(out)
    provenance.append(source_record(title_path,None,1))
    textures["title"]={"path":"res://assets/ui/title.png","source_frame":1,"crop":[0,0,550,265],
                       "purpose":"title artwork above the interactive menu; excludes original start button",
                       "output":output_record(out)}
    audio={"music":{},"sfx":{}};audio_records={}
    for name,filename in [("title","1602.mp3"),("battle","7130.mp3")]:
        row=copy_asset(Path("external/BGM")/filename,Path("audio")/filename,previous,provenance)
        audio["music"][name]=row["path"];audio_records[name]=row
    audio_events={
        "basic":{"sprite_id":4637,"frame":7,"sound_id":4421,"in_point_samples_44100":0,"envelope":[{"sample":0,"left":12399,"right":13875}]},
        "skill":{"sprite_id":4685,"frame":2,"sound_id":4678,"in_point_samples_44100":0,"envelope":[{"sample":0,"left":12694,"right":11808}]},
        "skill_fire":{"sprite_id":4685,"frame":5,"sound_id":4458,"in_point_samples_44100":3900,"envelope":[{"sample":0,"left":13284,"right":12694}]},
        "enemy_attack":{"sprite_id":3898,"frame":27,"sound_id":3876,"in_point_samples_44100":0,"envelope":[]},
        "death":{"sprite_id":3897,"frame":13,"sound_id":3896,"in_point_samples_44100":0,"envelope":[{"sample":0,"left":3227,"right":5461},{"sample":0,"left":7696,"right":9185}]},
        "crt0_basic2":{"sprite_id":4638,"frame":2,"sound_id":4421,"in_point_samples_44100":0,"envelope":[{"sample":0,"left":12694,"right":13580}]},
        "crt0_basic3":{"sprite_id":4639,"frame":2,"also_frames":[15],"sound_id":4421,"in_point_samples_44100":0,"envelope":[{"sample":0,"left":12989,"right":11808}]},
        "crt0_basic5":{"sprite_id":4699,"frame":2,"sound_id":4421,"in_point_samples_44100":0,"out_point_samples_44100":68943,"envelope":[{"sample":0,"left":12694,"right":13284}]},
        "crt0_basic6_charge":{"sprite_id":4648,"frame":5,"sound_id":4640,"in_point_samples_44100":0,"envelope":[{"sample":0,"left":8266,"right":7971}]},
        "crt0_basic6":{"sprite_id":4648,"frame":6,"sound_id":4421,"in_point_samples_44100":0,"envelope":[{"sample":0,"left":13284,"right":13284}]},
        "crt0_skill_s_charge":{"sprite_id":4668,"frame":2,"sound_id":4649,"in_point_samples_44100":0,"envelope":[]},
        "crt0_skill_s":{"sprite_id":4668,"frame":6,"sound_id":4421,"in_point_samples_44100":0,"envelope":[{"sample":0,"left":12694,"right":11808}]},
        "crt1_basic":{"sprite_id":4860,"frame":6,"sound_id":4859,"in_point_samples_44100":600,"envelope":[{"sample":0,"left":16532,"right":16236}]},
        "crt1_skill_s_charge":{"sprite_id":4917,"frame":2,"sound_id":4649,"in_point_samples_44100":0,"envelope":[]},
        "crt1_skill_s":{"sprite_id":4917,"frame":7,"sound_id":4859,"in_point_samples_44100":1000,"envelope":[{"sample":0,"left":15941,"right":16827},{"sample":0,"left":15941,"right":16827}]},
        "move":{"sprite_id":4841,"also_sprite_ids":[4617],"frame":7,"sound_id":4616,"in_point_samples_44100":0,"envelope":[]},
        "boss7176_attack":{"sprite_id":7170,"frame":10,"also_frames":[22,34,51],"sound_id":7164,"in_point_samples_44100":0,"envelope":[]},
        "boss7176_death":{"sprite_id":7169,"frame":6,"sound_id":3896,"in_point_samples_44100":0,"envelope":[{"sample":0,"left":17122,"right":18303}]},
        "player_hit_fx":{"sprite_id":4689,"frame":2,"sound_id":4688,"in_point_samples_44100":0,"envelope":[{"sample":0,"left":15351,"right":16236}]},
        "crt0_jump_takeoff":{"sprite_id":5633,"frame":2,"sound_id":4624,"in_point_samples_44100":0,"envelope":[]},
        "crt0_jump_land":{"sprite_id":5633,"frame":31,"sound_id":4616,"in_point_samples_44100":0,"envelope":[]},
        "crt0_air_shot":{"sprite_id":5628,"frame":2,"sound_id":4421,"in_point_samples_44100":0,"envelope":[{"sample":0,"left":12103,"right":11808}]},
        "crt0_down_start":{"sprite_id":4672,"frame":2,"sound_id":4624,"in_point_samples_44100":0,"envelope":[]},
        "crt0_down_end":{"sprite_id":4672,"frame":11,"sound_id":4616,"in_point_samples_44100":0,"envelope":[]},
        "crt0_z_swing":{"sprite_id":4622,"frame":6,"sound_id":4620,"in_point_samples_44100":2500,"envelope":[{"sample":0,"left":10332,"right":9447}]},
        "crt0_z_effect":{"sprite_id":4622,"frame":6,"sound_id":4621,"in_point_samples_44100":0,"out_point_samples_44100":59904,"envelope":[{"sample":0,"left":9077,"right":8000}]},
        "crt0_move_z":{"sprite_id":4625,"frame":7,"sound_id":4624,"in_point_samples_44100":0,"envelope":[]},
    }
    audio_file_records={}
    for name,event in audio_events.items():
        filename=str(event["sound_id"])+".mp3"
        if filename not in audio_file_records:
            audio_file_records[filename]=copy_asset(Path("sounds")/filename,Path("audio")/filename,previous,provenance,event["sound_id"])
        row=audio_file_records[filename]
        audio["sfx"][name]=row["path"];audio_records[name]=row
    font=copy_asset(Path("fonts/1557_HYHeadLine-Medium.ttf"),Path("fonts/ui.ttf"),previous,provenance,1557)
    # Local-space rectangles are derived from source bounds and nested matrices.
    geometry={
        "crt0_body":{"rect":[-28.2,-67.05,65.8,141.0],"space":"sprite6732","source_id":4547,"placement_twips":[94,1449]},
        "enemy_body":{"rect":[-55.96760495,-173.622184095,104.77960371,172.400006745],"space":"sprite4030","source_id":1119,"placement_twips":[-155,-1554],"source_scale":[.9993286,.9997101],"placement_chain":[{"parent_id":4030,"child_id":3898,"frame":1,"translate_twips":[0,-1325]},{"parent_id":3898,"child_id":1119,"frame":1,"translate_twips":[-155,-229]}]},
        "enemy_melee":{"rect":[-74.35,-138.8,121.85,114.6],"space":"sprite4030","source_id":3875,"placement_twips":[-263,-1630]},
        "skill_d":{"rect":[39.290140562,-204.40454088,95.219718876,331.70908176],"space":"sprite6732","source_id":4684,"placement_twips":[1738,-771],"source_scale":[.71647644,3.8215332]},
        "projectile_default":{"rect":[-7.5,-6.3,14.85,12.65],"space":"sprite542","source_id":542,"default_child_id":541,"default_child_frame":1,"source_bounds_twips":[-150,-126,147,127],"filter_bounds_twips":[-290,-266,287,267],"source_scale":[1.2250977,1.6338501],"timeline_x_twips":[2060,2725,3391,4058,4724,5390,6056,6723,7389,8056],"timeline_y_twips":-75,"note":"Default eun=zak=0; 541 and 542 stop on frame 1. No separate invisible hit sprite; gradient transparency and filter expansion are not image-alpha hitbox rules."},
    }
    geometry["enemy_air_body"]={"rect":[-41.21760495,-177.572184095,104.77960371,172.400006745],"space":"outer actor4030 or7176","source_id":1119,"source_scale":[.9993286,.9997101],"placement_chain":[{"parent_ids":[4030,7176],"frame":2,"child_id":4029,"translate_twips":[115,-1827]},{"parent_id":4029,"frame":1,"child_id":1119,"translate_twips":[25,194]}]}
    geometry["air_hit_markers"]={
        "4030":{"animation":"air_hit_marker","source_id":3889,"parent_id":4028,"parent_frame":1,"offset_px":[-10.9,-32.05],"scale":[.70036316,.8067169],"placement_twips":[-376,-508],"outer_parent_twips":[158,-133],"removed_parent_frame":2},
        "7176":{"animation":"air_hit_marker","source_id":3889,"parent_id":7175,"parent_frame":1,"offset_px":[-16.5,-22.95],"scale":[.70036316,.8067169],"placement_twips":[-330,761],"outer_parent_twips":[0,-1220],"removed_parent_frame":2},
    }
    geometry["player_hit_fx"]={
        key:{"animation":"player_hit_fx","source_id":4689,"parent_id":6732,"parent_frame":frame,
             "offset_px":[x/20,703/20],"scale":[1.0,1.0],"source_scale":[.3622589,.3516693],
             "placement_twips":[x,703],"baked_parent_transform":True,
             "filter":{"type":"glow","rgba":[255,102,0,255],"blur":[5.0,5.0],"strength":4.296875,"passes":1,"composite_source":True},
             "trigger_body_source_frame":2,"trigger_fx_source_frame":2,"stop_source_frame":8,
             "note":"Atlas bakes original parent scale and glow; apply only offset and actor root transform, never source_scale twice. FX is a sibling of the body, not part of body atlases."}
        for key,frame,x in [("crt_0",14,344),("crt_1",44,294)]
    }
    geometry["crt1_body"]={**geometry["crt0_body"],"note":"Sprite6732 frame30 body4547 placement equals crt0; parent37/42 uses the same body at depth572."}
    geometry.update(m1_geometry())
    for name,ident,x_positions in [
        ("projectile_rising",1472,[2080,2748,3417,4085,4754,5422,6091,6759,7428,8096]),
        ("projectile_strong",1473,[2080,2764,3448,4132,4816,5500,6184,6868,7552,8236]),
    ]:
        geometry[name]={**geometry["projectile_default"],"timeline_sprite_id":ident,"timeline_x_twips":x_positions,
            "note":"Default 541/542 frame1 geometry; ten placed frames then remove at11. No damage multiplier inferred from linkage name."}
    outputs=[v["output"] for v in animations.values()]+[v["output"] for v in textures.values()]+[v["output"] for v in audio_records.values()]+[font["output"]]
    outputs=list({row["path"]:row for row in outputs}.values())
    # Every source read is rehashed after generation; a changed input fails the job.
    unique={v["path"]:v for v in provenance}
    for row in unique.values():
        if sha256(WORKSPACE/row["path"]) != row["sha256"]:
            raise RuntimeError(f"Source changed during generation: {row['path']}")
    catalog={"schema_version":1,"source_swf":{"path":SWF.relative_to(WORKSPACE).as_posix(),"sha256":sha256(SWF)},
        "source_frame_rate":25,"animations":animations,"textures":textures,"audio":audio,"audio_records":audio_records,"audio_events":audio_events,
        "fonts":{"ui":font["path"]},"font_records":{"ui":font},"source_geometry":geometry,
        "stage_2_placements":{"player":{"position":[129.35,312.9],"scale":[.6369171,.65245056]},"enemy":{"position":[411.2,363.7],"scale":[.52941895,.51246643]},"forest":{"position":[279.35,311.2],"scale":[1.,1.]}},
        "stage_4_placements":{"player":{"position":[273.35,314.9],"scale":[.6369171,.65245056]},"enemies":[{"instance":name,"source_id":4030,"position":[x,363.7],"scale":[.52941895,.51246643]} for name,x in [("적",494.9),("적2",411.45),("적3",168.5),("적4",50.4)]],"forest":{"position":[279.35,311.2],"scale":[1.,1.]},"dialogue_id":7142},
        "render_profiles":{"crt0_default_equipment":{"freeze_first_frame_ids":FROZEN_SELECTORS,"hide_instances":{"3588":["wing","전펙"],"3620":["wing"]},"original_default_state":{"crt":0,"스핏압":1,"스핏무기":0,"스핏마스터":0,"pren":0,"wing":"undefined in fresh save; only value 1 shows wings"},"method":"FFDec in-memory SWF copy; selector clips retain first ShowFrame only, hidden placements omitted; original file never saved or modified"}},
        "conversion_environment":{"ffdec":"26.2.1","pillow":PILLOW_VERSION,"render_zoom":1.0,"antialias_scale":1},
        "ffdec_bounds":{str(k):v for k,v in bounds.items()},"sources":list(unique.values()),"outputs":outputs,
        "limitations":["Static FFDec PNGs preserve selected parent timeline frames but do not execute nested AS.","No original collision shapes are approximated from alpha pixels; source bounds/matrices are recorded separately.","UI font is an embedded source subset, not a complete Chinese font; missing UI glyphs require explicit fallback."]}
    CATALOG.parent.mkdir(parents=True,exist_ok=True)
    catalog["render_profiles"]["projectile_default"]={"freeze_first_frame_ids":[541,542],"original_default_state":{"eun":0,"zak":0},"method":"In-memory SWF first-frame selection follows both stop() scripts; enclosing sprite1474 retains all ten motion frames."}
    catalog["render_profiles"]["crt1_default_equipment"]={"freeze_first_frame_ids":FROZEN_SELECTORS,"hide_instances":{"3588":["wing","전펙"],"3620":["wing"]},"original_default_state":{"crt":1,"렌저압":1,"레인저무기":0,"레인저마스터":0,"pren":0},"method":"Same in-memory selector handling; default weapon4543 remains frame1, clothing3725 and detail3763 stop on frame1."}
    catalog["render_profiles"]["boss7176_source"]={"freeze_first_frame_ids":[],"method":"FFDec selected source frames with nested transforms; no boss costume selector identified. Source default faces left. 7168 already mirrors inner7158."}
    catalog["render_profiles"]["air_pose_only"]={"source_ids":[4028,7175],"hide_instances":{"4028":["타격"],"7175":["타격"]},"method":"In-memory removal of independent hit-marker placements only; two source stop poses retained. 4028 frame2 embeds static4027. Actor geometry and marker clock are separate runtime responsibilities.","source_facing":-1,"pose_switch_source":"root enemy enterFrame_2: gravity<=1 outer2/air1; _3: gravity>0 air2; _4: gravity_acceleration==0 outer1"}
    catalog["render_profiles"]["air_hit_marker"]={"source_id":3889,"source_frames":list(range(1,9)),"method":"Unmodified selected marker frames; 1..7 visible, frame8 removes shape and stop. Source frame2 also updates combo; actor damage events are not baked into textures."}
    catalog["render_profiles"]["player_hit_fx"]={"source_id":4689,"source_frames":list(range(1,9)),"source_parent_id":6732,"source_parent_frames":[14,44],"method":"In-memory wrapper clones source parent14 PlaceObject3_4689 with original scale and glow, zeros translation, and advances eight source frames. Parent44 differs only in translation, supplied by source_geometry. Original SWF never saved. Frame8 removes graphics and stops; no permanent FX baked into hit body atlases.","baked_scale":[.3622589,.3516693],"translation_applied_by_runtime":True}
    catalog["render_profiles"]["crt0_jump_base"]={"source_id":5633,"source_frames":list(range(1,36)),"freeze_first_frame_ids":[5627],"separate_child_id":5628,"method":"In-memory copy retains parent timing, takeoff/rise/landing and invisible source helpers; removes only placements and subsequent depth1 changes belonging to independent child5628. Export child5628 separately. Its per-parent-frame matrices are in source_geometry.crt0_jump; do not bake or auto-loop firing. Original SWF remains read-only."}
    catalog["limitations"].extend(["crt0_skill_s includes control frame5 gotoAndPlay(6); frame availability is not a claim of one tick per frame. Exact same-tick AS scheduling awaits source runtime trace.","Source4917 parent scaleX1.000412 is metadata, applied by SourceSprite; source pixels remain unresampled."])
    # A base refresh must retain separately registered ACT02 outputs. Otherwise
    # subsequent selective stages correctly refuse to overwrite files that the
    # base refresh itself accidentally made unregistered.
    def merge_registered(prior,generated):
        result=dict(prior)
        for key,value in generated.items():
            if isinstance(value,dict)and isinstance(result.get(key),dict):result[key]=merge_registered(result[key],value)
            elif key in("sources","outputs")and isinstance(value,list):result[key]=list({r["path"]:r for r in [*result.get(key,[]),*value]}.values())
            elif key=="limitations":result[key]=list(dict.fromkeys([*result.get(key,[]),*value]))
            else:result[key]=value
        return result
    catalog=merge_registered(old,catalog)
    CATALOG.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"animations":len(animations),"source_files":len(unique),"output_files":len(outputs),"output_bytes":sum(v["bytes"] for v in outputs),"catalog":str(CATALOG)},ensure_ascii=False))


def read_source_symbols(wanted: set[int]) -> dict:
    """Bounded XML metadata query; retain only explicitly requested definitions."""
    symbols={};stack=[]
    for event,element in ET.iterparse(SOURCES/"structure/game.xml",events=("start","end")):
        if event=="start":stack.append(element);continue
        if len(stack)==3 and element.tag=="item":
            ident=next((element.get(k) for k in ("spriteId","shapeId","buttonId","characterID","textId","fontID","soundId") if element.get(k) is not None),None)
            auxiliary=element.get("type") in ("DefineFontAlignZonesTag","DefineFontNameTag","DefineFontInfoTag","DefineFontInfo2Tag","DefineButtonSoundTag","DefineButtonCxformTag")
            if ident is not None and int(ident) in wanted and not auxiliary:symbols[int(ident)]=element
            else:element.clear()
        stack.pop()
    if set(symbols)!=wanted:raise ValueError(f"Missing original XML definitions: {wanted-set(symbols)}")
    return symbols


def source_matrix(a: dict) -> list:
    return [float(a.get("scaleX",1)),float(a.get("rotateSkew0",0)),float(a.get("rotateSkew1",0)),float(a.get("scaleY",1)),int(a.get("translateX",0))/20,int(a.get("translateY",0))/20]


def source_frames(sprite) -> dict:
    state={};result={};frame=1
    for tag in sprite.find("subTags"):
        typ=tag.get("type","");depth=tag.get("depth")
        if typ.startswith("PlaceObject"):
            row=state.get(depth,{}).copy() if tag.get("placeFlagMove")=="true" else {}
            row.update(tag.attrib)
            for key in ("matrix","colorTransform"):
                if tag.find(key) is not None:row[key]=dict(tag.find(key).attrib)
            state[depth]=row
        elif typ.startswith("RemoveObject"):state.pop(depth,None)
        elif typ=="ShowFrameTag":result[frame]={k:v.copy() for k,v in state.items()};frame+=1
    return result


def selected_root_placements(wanted: set[int], selected_frames: set[int]) -> dict:
    """Read the effective root display list for explicitly requested UI actors."""
    state={};result={};stack=[];frame=1
    for event,e in ET.iterparse(SOURCES/"structure/game.xml",events=("start","end")):
        if event=="start":stack.append(e);continue
        if len(stack)==3 and e.tag=="item":
            typ=e.get("type","");depth=e.get("depth")
            if typ.startswith("PlaceObject"):
                ident=e.get("characterId")
                if ident is not None and int(ident)not in wanted:state.pop(depth,None)
                elif ident is not None or depth in state:
                    row=state.get(depth,{}).copy() if e.get("placeFlagMove")=="true" else{}
                    row.update(e.attrib)
                    if e.find("matrix")is not None:row["matrix"]=dict(e.find("matrix").attrib)
                    state[depth]=row
            elif typ.startswith("RemoveObject"):state.pop(depth,None)
            elif typ=="ShowFrameTag":
                if frame in selected_frames:result[str(frame)]=[{"source_id":int(r["characterId"]),"depth":int(r["depth"]),"name":r.get("name"),"matrix":source_matrix(r.get("matrix",{}))}for r in state.values()]
                frame+=1
            e.clear()
        stack.pop()
        if frame>max(selected_frames):break
    if set(result)!={str(f)for f in selected_frames}:raise ValueError("Missing selected root source pages")
    return result


def build_source_ui():
    """Only training/normal-battle menu, failure and settings source components."""
    verify_catalog();catalog=json.loads(CATALOG.read_text(encoding="utf-8"));previous={r["path"]:r["sha256"]for r in catalog["outputs"]}
    buttons={"close":6943,"menu_retry":6950,"menu_return":6953,"failure_retry":6909,"failure_return":6912,"quality_high":1959,"quality_medium":1961,"quality_low":1963}
    specs={"source_menu_keys":{"source_id":6956,"mode":"screen_static_2"},"source_menu_actions":{"source_id":6956,"mode":"screen_static_3"},"source_settings_panel":{"source_id":6956,"mode":"screen_static_6"},"source_failure_panel":{"source_id":6917,"mode":"screen_static_2"}}
    for name,ident in buttons.items():
        for state in("up","over","down"):specs[f"source_{name}_{state}"]={"source_id":ident,"mode":"button_"+state}
    for page,volume in enumerate((100,75,50,25,0),1):specs[f"source_volume_{volume}"]={"source_id":1974,"mode":f"sprite_frame_{page}_static"}
    specs.update({"source_checkbox_off":{"source_id":1981,"mode":"sprite_frame_1_static"},"source_checkbox_on":{"source_id":1981,"mode":"sprite_frame_2_static"}})
    symbols=read_source_symbols({6956,6917,1974,1981,1983,1965,1967,1969,1971,1973,*buttons.values()})
    hit_children={int(r.get("characterId"))for ident in buttons.values()for r in symbols[ident].find("characters")if r.get("buttonStateHitTest")=="true"}
    hit_bounds=flash_bounds(sorted(hit_children|{1965,1967,1969,1971,1973,1981}))
    def transformed(rect,matrix):
        x0,y0,x1,y1=rect;pts=[(matrix[0]*x+matrix[2]*y+matrix[4],matrix[1]*x+matrix[3]*y+matrix[5])for x,y in((x0,y0),(x1,y0),(x0,y1),(x1,y1))]
        xs=[p[0]for p in pts];ys=[p[1]for p in pts];return[min(xs),min(ys),max(xs),max(ys)]
    def local_rect(ident):return[v/20 for v in hit_bounds[ident]["stroke_twips"]]
    button_geometry={}
    for name,ident in buttons.items():
        records=[];rects=[]
        for r in symbols[ident].find("characters"):
            if r.get("buttonStateHitTest")!="true":continue
            child=int(r.get("characterId"));matrix=source_matrix(dict(r.find("placeMatrix").attrib));rect=transformed(local_rect(child),matrix)
            records.append({"source_id":child,"matrix":matrix,"bounds_source_local":local_rect(child)});rects.append(rect)
        box=[min(r[0]for r in rects),min(r[1]for r in rects),max(r[2]for r in rects),max(r[3]for r in rects)]
        button_geometry[name]={"source_id":ident,"textures":{state:f"source_{name}_{state}"for state in("up","over","down")},"source_hit_records":records,"hit_rect_local":[box[0],box[1],box[2]-box[0],box[3]-box[1]],"hit_rule":"AABB union of original hit-state records transformed shape/text bounds, excluding visual filters; not cropped PNG alpha."}
    def row(ident,frame,child):
        r=next(r for r in source_frames(symbols[ident])[frame].values()if r.get("characterId")==str(child));return{"source_id":child,"depth":int(r["depth"]),"matrix":source_matrix(r.get("matrix",{}))}
    panels={"keys":{"source_id":6956,"source_frame":2,"texture":"source_menu_keys","buttons":{"close":row(6956,2,6943)}},"actions":{"source_id":6956,"source_frame":3,"texture":"source_menu_actions","buttons":{name:row(6956,3,buttons[name])for name in("close","menu_retry","menu_return")}},"settings":{"source_id":6956,"source_frame":6,"texture":"source_settings_panel","buttons":{name:row(6956,6,buttons[name])for name in("close","quality_high","quality_medium","quality_low")}},"failure":{"source_id":6917,"source_frame":2,"texture":"source_failure_panel","buttons":{name:row(6917,2,buttons[name])for name in("failure_retry","failure_return")}}}
    volume={"source_id":1974,"placement":row(6956,6,1974),"image_by_volume":{str(volume):f"source_volume_{volume}"for volume in(100,75,50,25,0)},"source_page_by_volume":{"100":1,"75":2,"50":3,"25":4,"0":5},"click_targets":[]}
    for ident,amount in((1965,0),(1967,25),(1969,50),(1971,75),(1973,100)):
        placement=row(1974,1,ident);rect=transformed(local_rect(ident),placement["matrix"]);volume["click_targets"].append({**placement,"volume_percent":amount,"hit_rect_volume_local":[rect[0],rect[1],rect[2]-rect[0],rect[3]-rect[1]]})
    volume["initial_page_rule"]="Source1974 frame1 divides currentSoundVolume/25; exact0/1/2/3 select5/4/3/2, all other values stay1. Original fresh80 therefore showspage1 without changing actual volume80."
    check=local_rect(1981);checkboxes={name:{"source_id":ident,"placement":row(6956,6,ident),"textures":{"0":"source_checkbox_off","1":"source_checkbox_on"},"hit_rect_local":[check[0],check[1],check[2]-check[0],check[3]-check[1]],"source_variable":variable}for name,ident,variable in(("auto_save",1981,"자동저장"),("auto_quality",1983,"자동화질"))}
    source_ui={"root_placements_by_source_frame":selected_root_placements({6956,6917,7346},{2,4,6,41}),"panels":panels,"buttons":button_geometry,"volume":volume,"checkboxes":checkboxes,
        "original_defaults":{"volume_percent":80,"volume_source":"DefineSprite_3841/frame_1/DoAction.as _root.onLoad","auto_quality":0,"auto_quality_source":"DefineSprite_3841/frame_1/DoAction.as","auto_save_new_start":0,"auto_save_source":"DefineButton2_1597/BUTTONCONDACTION on(release).as","save_slots":{"auto_save":47,"auto_quality":85},"existing_settings":"Keep existing user values. Original defaults do not authorize overwriting current Godot saves/preferences."},
        "quality_buttons":{"high":"HIGH","medium":"MEDIUM","low":"LOW","boundary":"These assign Flash _quality; equivalence to a Godot rendering setting is unproved. Keep any unsupported mapping visible rather than reporting false success."},
        "panel_rule":"Static backgrounds exclude independent buttons, live EditText and settings controls. All textures retain exact source local registration; apply source root matrix then recorded panel-child matrix once.","not_included":["other inventory professions/pages","tower failure variant","full Flash quality emulation"]}
    provenance=[source_record(SWF),source_record(SOURCES/"structure/game.xml")]
    for ident in {6956,6917,1974,1981,1983,*buttons.values()}:
        for prefix in("DefineSprite","DefineButton2"):
            provenance.extend(source_record(p)for p in(SOURCES/"scripts"/f"{prefix}_{ident}").rglob("*.as"))
    for rel in("DefineSprite_3841/frame_1/DoAction.as","DefineButton2_1597/BUTTONCONDACTION on(release).as","frame_1/DoAction_2.as"):provenance.append(source_record(SOURCES/"scripts"/rel))
    with tempfile.TemporaryDirectory(prefix="leba_source_ui_")as temp:
        images,bounds=render_ui_frames(Path(temp),specs)
        for key,spec in specs.items():catalog["textures"][key]=store_ui_texture(key,images[key],bounds[key],{**spec,"purpose":"Original battle menu/failure/settings component; runtime supplies state and interaction"},previous)
    prior_ui=catalog["source_geometry"].get("source_ui",{})
    source_ui["buttons"]={**prior_ui.get("buttons",{}),**source_ui["buttons"]}
    catalog["source_geometry"]["source_ui"]={**prior_ui,**source_ui}
    sources={r["path"]:r for r in catalog["sources"]};sources.update({r["path"]:r for r in provenance});catalog["sources"]=list(sources.values())
    outputs={r["path"]:r for r in catalog["outputs"]}
    for key in specs:r=catalog["textures"][key]["output"];outputs[r["path"]]=r
    catalog["outputs"]=list(outputs.values());CATALOG.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+"\n",encoding="utf-8");verify_catalog()
    print(json.dumps({"source_ui_textures":list(specs),"old_outputs_unchanged":sum(sha256(PROJECT/p)==h for p,h in previous.items())},ensure_ascii=False))


def source_button_geometry(buttons: dict, symbols: dict) -> dict:
    """Exact button hit-state records; image crop never defines interaction."""
    children={int(r.get("characterId"))for ident in buttons.values()for r in symbols[ident].find("characters")if r.get("buttonStateHitTest")=="true"}
    bounds=flash_bounds(sorted(children));result={}
    for name,ident in buttons.items():
        records=[];points=[]
        for r in symbols[ident].find("characters"):
            if r.get("buttonStateHitTest")!="true":continue
            child=int(r.get("characterId"));matrix=source_matrix(dict(r.find("placeMatrix").attrib));rect=[v/20 for v in bounds[child]["stroke_twips"]]
            records.append({"source_id":child,"matrix":matrix,"bounds_source_local":rect})
            for x,y in((rect[0],rect[1]),(rect[2],rect[1]),(rect[0],rect[3]),(rect[2],rect[3])):points.append((matrix[0]*x+matrix[2]*y+matrix[4],matrix[1]*x+matrix[3]*y+matrix[5]))
        xs=[p[0]for p in points];ys=[p[1]for p in points]
        result[name]={"source_id":ident,"textures":{state:f"source_{name}_{state}"for state in("up","over","down")},"source_hit_records":records,"hit_rect_local":[min(xs),min(ys),max(xs)-min(xs),max(ys)-min(ys)],"hit_rule":"Original hit-state record AABB excluding visual filters; never cropped PNG alpha."}
    return result


def publish_source_ui_parts(catalog, previous, specs, provenance):
    with tempfile.TemporaryDirectory(prefix="leba_source_ui_parts_")as temp:
        images,bounds=render_ui_frames(Path(temp),specs)
        for key,spec in specs.items():catalog["textures"][key]=store_ui_texture(key,images[key],bounds[key],{**spec,"purpose":"Original battle UI component; dynamic state remains in runtime"},previous)
    sources={r["path"]:r for r in catalog["sources"]};sources.update({r["path"]:r for r in provenance});catalog["sources"]=list(sources.values())
    outputs={r["path"]:r for r in catalog["outputs"]}
    for key in specs:r=catalog["textures"][key]["output"];outputs[r["path"]]=r
    catalog["outputs"]=list(outputs.values());CATALOG.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+"\n",encoding="utf-8");verify_catalog()
    print(json.dumps({"source_ui_parts":list(specs),"old_outputs_unchanged":sum(sha256(PROJECT/p)==h for p,h in previous.items())},ensure_ascii=False))


def build_source_dropdown():
    verify_catalog();catalog=json.loads(CATALOG.read_text(encoding="utf-8"));previous={r["path"]:r["sha256"]for r in catalog["outputs"]}
    buttons={"dropdown_settings":6931,"dropdown_actions":6932,"dropdown_keys":6933}
    symbols=read_source_symbols({6934,6920,1965,1967,1969,1971,1973,1977,1980,*buttons.values()})
    specs={f"source_{name}_{state}":{"source_id":ident,"mode":"button_"+state}for name,ident in buttons.items()for state in("up","over","down")}
    specs["source_dropdown_top"]={"source_id":6920,"mode":"symbol"}
    for ident in(6924,6927,6930):specs[f"source_dropdown_transition_{ident}"]={"source_id":ident,"mode":"symbol"}
    frames={};placements={};by_id={v:k for k,v in buttons.items()}
    targets={6931:("settings",6),6932:("actions",3),6933:("keys",2)}
    for frame,rows in source_frames(symbols[6934]).items():
        frames[str(frame)]=[]
        for r in rows.values():
            ident=int(r["characterId"]);entry={"source_id":ident,"depth":int(r["depth"]),"matrix":source_matrix(r.get("matrix",{}))}
            if ident in by_id:entry["button_key"]=by_id[ident]
            else:entry["texture"]="source_dropdown_top"if ident==6920 else f"source_dropdown_transition_{ident}"
            frames[str(frame)].append(entry)
            if frame==7 and ident in by_id:placements[by_id[ident]]={**entry,"target_panel":targets[ident][0],"target_source_frame":targets[ident][1]}
    box=[v/20 for v in flash_bounds([6920])[6920]["stroke_twips"]]
    top=next(r for r in frames["1"]if r["source_id"]==6920).copy();top["hit_rect_local"]=[box[0],box[1],box[2]-box[0],box[3]-box[1]]
    ui=catalog["source_geometry"]["source_ui"];ui["buttons"].update(source_button_geometry(buttons,symbols))
    ui["dropdown"]={"source_id":6934,"root_placements_by_source_frame":selected_root_placements({6934},{2,4,6,41}),"top":top,"buttons":placements,"frames":frames,"source_fps":25,"stop_frames":[1,7],"control_events":{"13":"gotoAndPlay(1)"},"click_rules":{"1":"top on(release) gotoAndPlay(2)","7":"top on(release) gotoAndPlay(8)","items":"First on(release) opens6956 target page; second on(release) resets6934 to1."},"hover_rule":"Top6920 is one-frame clip with on(release), not rollOver/rollOut; items retain native three-state button art."}
    ui["settings_mouse_states"]={"volume_targets":"1965/1967/1969/1971/1973 are one-frame clips with on(release); no distinct hover/down source art.","checkboxes":"1977/1980 are one-frame clips; source1981/1983 pages are boolean off/on, not hover/down variants."}
    provenance=[]
    for ident in{6934,*buttons.values()}:
        for prefix in("DefineSprite","DefineButton2"):provenance.extend(source_record(p)for p in(SOURCES/"scripts"/f"{prefix}_{ident}").rglob("*.as"))
    publish_source_ui_parts(catalog,previous,specs,provenance)


def build_source_warehouse():
    """Default CRT0 inventory page and existing HP+10 ring path only."""
    verify_catalog();catalog=json.loads(CATALOG.read_text(encoding="utf-8"));previous={r["path"]:r["sha256"]for r in catalog["outputs"]}
    buttons={"warehouse_close":2050,"warehouse_rings":2073,"warehouse_weapons":2635,"ring_cancel":2513,"ring_equip_crt0":2539,"ring_equip_crt1":2540,"ring_equip_crt2":2541,"ring_equip_crt3":2542,"ring_unequip":2308}
    ids={7346,2728,2615,2721,2348,2349,2401,2444,2502,2082,2109,2617,2618,2671,2672,2673,*buttons.values()}
    symbols=read_source_symbols(ids)
    specs={"source_warehouse_weapons_panel":{"source_id":2728,"mode":"warehouse_static_2"},"source_warehouse_rings_panel":{"source_id":2728,"mode":"warehouse_static_8"},"source_ring_owned":{"source_id":2304,"mode":"symbol"},"source_ring_choose_panel":{"source_id":2615,"mode":"screen_static_8"}}
    for name,ident in buttons.items():
        for state in("up","over","down"):specs[f"source_{name}_{state}"]={"source_id":ident,"mode":"button_"+state}
    def row(ident,frame,child):
        r=next(r for r in source_frames(symbols[ident])[frame].values()if r.get("characterId")==str(child));return{"source_id":child,"depth":int(r["depth"]),"matrix":source_matrix(r.get("matrix",{}))}
    def field(ident,frame,child):
        e=symbols[child];b=e.find("bounds");return{**row(ident,frame,child),"source_variable":e.get("variableName"),"font_id":int(e.get("fontId")),"font_size_px":int(e.get("fontHeight"))/20,"align":int(e.get("align")),"bounds_local":[int(b.get(k))/20 for k in("Xmin","Ymin","Xmax","Ymax")],"source_initial_text":e.get("initialText"),"initial_text_rule":"Editor placeholder is not player progress; runtime reads current profile, unknown values must remain explicitly unavailable."}
    ui=catalog["source_geometry"]["source_ui"];ui["buttons"].update(source_button_geometry(buttons,symbols))
    panel_buttons={"2":{"warehouse_close":row(2728,2,2050),"warehouse_rings":row(2728,2,2073)},"8":{"warehouse_close":row(2728,8,2050),"warehouse_weapons":row(2728,8,2635)}}
    for rows in panel_buttons.values():
        for name,r in rows.items():r["button_key"]=name
    pages={}
    for f,tex,fields in((2,"source_warehouse_weapons_panel",(2109,2617,2618)),(8,"source_warehouse_rings_panel",(2671,2672,2673))):
        pages[str(f)]={"source_frame":f,"texture":tex,"buttons":panel_buttons[str(f)],"fields":{name:field(2728,f,child)for name,child in zip(("gold","clear_cubes","pama_stones"),fields)}}
    pages={**ui.get("warehouse",{}).get("pages",{}),**pages}
    popup_buttons={name:{**row(2615,8,ident),"button_key":name}for name,ident in buttons.items()if name.startswith("ring_equip_")or name=="ring_cancel"}
    equip={}
    for char,group in(("crt_0",2444),("crt_1",2502),("crt_2",2349),("crt_3",2401)):
        equip[char]={"group":row(2728,8,group),"ring_slot":row(group,4,2348),"button":{**row(2348,2,2308),"button_key":"ring_unequip"},"visibility":"profile.equipment.rings[character_id] ==1; source2348 selects(root character ring slot+1)."}
    b=[v/20 for v in flash_bounds([2082])[2082]["stroke_twips"]]
    ui["warehouse"]={"source_id":2728,"root_container_id":7346,"root_placements_by_source_frame":selected_root_placements({7346},{2,4,6,41}),"container_matrix":row(7346,1,2728)["matrix"],"pages":pages,"initial_source_page":2,
        "ring_inventory":{"placement":row(2728,8,2721),"icon":{**row(2721,2,2304),"texture":"source_ring_owned"},"click_target":{**row(2721,2,2082),"hit_rect_local":[b[0],b[1],b[2]-b[0],b[3]-b[1]]},"source_owned_variable":"하링","visible_if":"profile.inventory.haring ==1","on_release":"2615.gotoAndStop(8)"},
        "equipped_rings":equip,"choose_ring":{"source_id":2615,"source_frame":8,"placement":row(2728,8,2615),"texture":"source_ring_choose_panel","buttons":popup_buttons},
        "render_rule":"Panels retain original empty source slots and category labels. Each page separately freezes item selectors to source1 (empty), equipment groups to1 for weaponpage2 or4 for ringpage8. Live EditText, popup2615 and only separately interactive buttons2050/2073/2635 are removed. Original unsupported category/arrow up art remains static; it is not implemented inventory navigation.",
        "transactions":"Reuse existing source-backed Progression: equip2539..2542 leaves owned flag; unequip2308 clears all four matching ring slots and restores owned flag. No purchase/sell invented in inventory.","scope":"Only page2 default weapon view and page8 existing HP+10 ring workflow. Other item/category selection is unimplemented; blank slots do not assert every unknown item is owned."}
    append_warehouse_control_metadata(catalog,symbols)
    provenance=[]
    for ident in{2728,2721,2615,2348,2349,2401,2444,2502,*buttons.values()}:
        for prefix in("DefineSprite","DefineButton2"):provenance.extend(source_record(p)for p in(SOURCES/"scripts"/f"{prefix}_{ident}").rglob("*.as"))
    publish_source_ui_parts(catalog,previous,specs,provenance)


def append_warehouse_control_metadata(catalog,symbols=None,pages=(2,8)):
    """Metadata only: unsupported source controls remain visible, never fake-live."""
    if symbols is None:symbols=read_source_symbols({2728,2349,2401,2444,2502,2109,2617,2618,2671,2672,2673})
    root_frames=source_frames(symbols[2728]);groups=(2349,2401,2444,2502)
    children={int(r["characterId"])for f in pages for r in root_frames[f].values()}
    children.update(int(r["characterId"])for i in groups for f in(1,4)for r in source_frames(symbols[i])[f].values())
    if 6 in pages:children.update(int(r["characterId"])for r in source_frames(symbols[2401])[2].values())
    definitions=read_source_symbols(children)
    buttons={f"unused_{i}":i for i,e in definitions.items()if e.get("type")=="DefineButton2Tag"}
    geometry=source_button_geometry(buttons,definitions)
    def multiply(a,b):return[a[0]*b[0]+a[2]*b[1],a[1]*b[0]+a[3]*b[1],a[0]*b[2]+a[2]*b[3],a[1]*b[2]+a[3]*b[3],a[0]*b[4]+a[2]*b[5]+a[4],a[1]*b[4]+a[3]*b[5]+a[5]]
    def control(r,parent=None):
        ident=int(r["characterId"]);g=geometry[f"unused_{ident}"];matrix=source_matrix(r.get("matrix",{}));entry={"source_id":ident,"depth":int(r["depth"]),"matrix":matrix if parent is None else multiply(parent["matrix"],matrix),"hit_rect_local":g["hit_rect_local"],"source_hit_records":g["source_hit_records"],"tooltip":"此原作分类或装备切换尚未接入。","render_rule":"Up artwork is already in the panel; overlay only transparent interaction feedback, do not draw a second copy."}
        if parent is not None:entry["source_parent"]=parent;entry["child_matrix"]=matrix
        return entry
    w=catalog["source_geometry"]["source_ui"]["warehouse"]
    for f in pages:
        records=[];enabled={r["source_id"]for r in w["pages"][str(f)]["buttons"].values()}
        for r in root_frames[f].values():
            ident=int(r["characterId"])
            # 1947/ddd is the transparent backing/cursor absorber, not a missing
            # category action. It must not become a full-screen warning target.
            if ident in buttons.values()and ident not in enabled and ident!=1947:records.append(control(r))
            if ident in groups:
                parent={"source_id":ident,"source_frame":2 if f==6 and ident==2401 else 4 if f==8 else 1,"depth":int(r["depth"]),"matrix":source_matrix(r.get("matrix",{}))}
                for child in source_frames(symbols[ident])[parent["source_frame"]].values():
                    if int(child["characterId"])in buttons.values():records.append(control(child,parent))
        w["pages"][str(f)]["unsupported_controls"]=records
        for field in w["pages"][str(f)]["fields"].values():
            e=symbols[field["source_id"]];color=e.find("textColor");field["color_rgba"]=[int(color.get(k,255))for k in("red","green","blue","alpha")]


def build_source_warehouse_crt1():
    """Bounded original2728 page3, not a relabeled CRT0 bitmap."""
    verify_catalog();catalog=json.loads(CATALOG.read_text(encoding="utf-8"));previous={r["path"]:r["sha256"]for r in catalog["outputs"]}
    ids={2728,2349,2401,2444,2502,2656,2657,2658,2639,2050,2635,2054,1557,2642,2644,2646,2648,2650,2652,2653,2654,2655}
    symbols=read_source_symbols(ids);state=source_frames(symbols[2728])[3]
    buttons={"warehouse_crt1_rings":2639}
    specs={"source_warehouse_crt1_weapons_panel":{"source_id":2728,"mode":"warehouse_static_3"}}
    for name,ident in buttons.items():
        for button_state in("up","over","down"):specs[f"source_{name}_{button_state}"]={"source_id":ident,"mode":"button_"+button_state}
    def row(child):
        r=next(r for r in state.values()if r.get("characterId")==str(child));return{"source_id":child,"depth":int(r["depth"]),"matrix":source_matrix(r.get("matrix",{}))}
    def field(child):
        e=symbols[child];b=e.find("bounds");return{**row(child),"source_variable":e.get("variableName"),"font_id":int(e.get("fontId")),"font_size_px":int(e.get("fontHeight"))/20,"align":int(e.get("align")),"bounds_local":[int(b.get(k))/20 for k in("Xmin","Ymin","Xmax","Ymax")],"source_initial_text":e.get("initialText"),"initial_text_rule":"Editor placeholder is not player progress; runtime reads current profile, unknown values stay explicitly unavailable."}
    ui=catalog["source_geometry"]["source_ui"];ui["buttons"].update(source_button_geometry(buttons,symbols))
    controls={name:{**row(ident),"button_key":name}for name,ident in(("warehouse_close",2050),("warehouse_weapons",2635),("warehouse_crt1_rings",2639))}
    ui["warehouse"]["pages"]["3"]={"source_frame":3,"texture":"source_warehouse_crt1_weapons_panel","buttons":controls,"fields":{name:field(child)for name,child in zip(("gold","clear_cubes","pama_stones"),(2656,2657,2658))},"source_title":"　漫游 武器","title_evidence":"Original DefineText2054 glyphEntries decoded through DefineFont3_1557 codeTable; page2 DefineText2053 decodes弹药 武器.","source_character_id":1,"render_rule":"Source2728 page3; all nine original CRT1 inventory selectors freeze at source1/empty. Four equipped-item group pages remain1. Live fields/popup and registered interactive buttons removed; unsupported categories retain original up art."}
    ui["warehouse"]["scope"]="Source2728 pages2(CRT0 weapon),3(CRT1 weapon),8(existing HP+10 ring workflow); unknown items stay empty/unavailable, no fabricated ownership or transaction."
    append_warehouse_control_metadata(catalog,symbols,pages=(3,))
    provenance=[source_record(SOURCES/"structure/game.xml")]
    for ident in ids|{2057}:
        for prefix in("DefineSprite","DefineButton2"):provenance.extend(source_record(p)for p in(SOURCES/"scripts"/f"{prefix}_{ident}").rglob("*.as"))
    publish_source_ui_parts(catalog,previous,specs,provenance)


def build_source_warehouse_crt2():
    """Bounded original2728 page4, not a relabeled CRT0 bitmap."""
    verify_catalog();catalog=json.loads(CATALOG.read_text(encoding="utf-8"));previous={r["path"]:r["sha256"]for r in catalog["outputs"]}
    ids={2728,2349,2401,2444,2502,2671,2672,2673,2639,2050,2635,2058,1557,2662,2663,2664,2665,2666,2667,2668,2669,2670}
    symbols=read_source_symbols(ids);state=source_frames(symbols[2728])[4]
    buttons={"warehouse_crt2_rings":2639}
    specs={"source_warehouse_crt2_weapons_panel":{"source_id":2728,"mode":"warehouse_static_4"}}
    for name,ident in buttons.items():
        for button_state in("up","over","down"):specs[f"source_{name}_{button_state}"]={"source_id":ident,"mode":"button_"+button_state}
    def row(child):
        r=next(r for r in state.values()if r.get("characterId")==str(child));return{"source_id":child,"depth":int(r["depth"]),"matrix":source_matrix(r.get("matrix",{}))}
    def field(child):
        e=symbols[child];b=e.find("bounds");return{**row(child),"source_variable":e.get("variableName"),"font_id":int(e.get("fontId")),"font_size_px":int(e.get("fontHeight"))/20,"align":int(e.get("align")),"bounds_local":[int(b.get(k))/20 for k in("Xmin","Ymin","Xmax","Ymax")],"source_initial_text":e.get("initialText"),"initial_text_rule":"Editor placeholder is not player progress; runtime reads current profile, unknown values stay explicitly unavailable."}
    ui=catalog["source_geometry"]["source_ui"];ui["buttons"].update(source_button_geometry(buttons,symbols))
    controls={name:{**row(ident),"button_key":name}for name,ident in(("warehouse_close",2050),("warehouse_weapons",2635),("warehouse_crt2_rings",2639))}
    ui["warehouse"]["pages"]["4"]={"source_frame":4,"texture":"source_warehouse_crt2_weapons_panel","buttons":controls,"fields":{name:field(child)for name,child in zip(("gold","clear_cubes","pama_stones"),(2671,2672,2673))},"source_title":"　狂战 武器","title_evidence":"Original page4 DefineText2058 through embedded font1557; source art is rendered without replacing its title.","source_character_id":2,"render_rule":"Source2728 page4; all nine original CRT2 inventory selectors freeze at source1/empty. Four equipped-item group pages remain1. Live fields/popup and registered interactive buttons removed; unsupported categories retain original up art."}
    ui["warehouse"]["scope"]="Source2728 pages2(CRT0 weapon),3(CRT1 weapon),4(CRT2 weapon),8(existing HP+10 ring workflow); unknown items stay empty/unavailable, no fabricated ownership or transaction."
    append_warehouse_control_metadata(catalog,symbols,pages=(4,))
    provenance=[source_record(SOURCES/"structure/game.xml")]
    for ident in ids|{2057}:
        for prefix in("DefineSprite","DefineButton2"):provenance.extend(source_record(p)for p in(SOURCES/"scripts"/f"{prefix}_{ident}").rglob("*.as"))
    publish_source_ui_parts(catalog,previous,specs,provenance)


def append_act02_hit_geometry():
    """Exact selected default collision placements, independent of art alpha."""
    verify_catalog();catalog=json.loads(CATALOG.read_text(encoding="utf-8"))
    requested={4744:{4723,4725,4727,1234},4777:{4771},4798:{1234},5678:{1234,5652,651},1108:{439},613:{224},603:{224},731:{224},1503:{1234},3916:{1140},6789:{6788},4433:{1140},4459:{1140},4483:{1140},4484:{1140}}
    shape_by_clip={224:223,439:299,651:650,1234:1232,4723:1407,4725:4724,4727:4726,4771:4770,5652:5651,1140:1139,6788:6787}
    symbols=read_source_symbols({*requested,*shape_by_clip,*shape_by_clip.values(),1105,1106,1107,207,205,206,4030,4029,1119,1118,7176,3898,7170,7157,7156,4021,3991,3990})
    def transform_rect(rect,m):
        x,y,w,h=rect;points=[(m[0]*xx+m[2]*yy+m[4],m[1]*xx+m[3]*yy+m[5])for xx,yy in ((x,y),(x+w,y),(x,y+h),(x+w,y+h))]
        xs=[p[0]for p in points];ys=[p[1]for p in points]
        return [round(min(xs),9),round(min(ys),9),round(max(xs)-min(xs),9),round(max(ys)-min(ys),9)]
    hit_shapes={}
    for clip,shape_id in shape_by_clip.items():
        first=list(source_frames(symbols[clip])[1].values())
        if len(first)!=1 or first[0].get("characterId")!=str(shape_id):raise ValueError(f"Collision default page changed for {clip}")
        bounds=symbols[shape_id].find("shapeBounds");rect=[int(bounds.get("Xmin"))/20,int(bounds.get("Ymin"))/20,(int(bounds.get("Xmax"))-int(bounds.get("Xmin")))/20,(int(bounds.get("Ymax"))-int(bounds.get("Ymin")))/20]
        matrix=source_matrix(first[0].get("matrix",{}))
        hit_shapes[str(clip)]={"source_frame":1,"shape_id":shape_id,"shape_bounds_twips":{k:int(bounds.get(k))for k in ("Xmin","Xmax","Ymin","Ymax")},"shape_matrix":matrix,"rect":transform_rect(rect,matrix)}
    timelines={};provenance=[source_record(SOURCES/"structure/game.xml")]
    for parent,children in requested.items():
        active={};timeline=source_frames(symbols[parent])
        for frame,rows in timeline.items():
            if parent==731 and frame not in [*range(1,11),*range(27,35)]:continue
            if parent==1503 and frame>30:continue
            hits=[]
            for row in rows.values():
                child=int(row.get("characterId",-1))
                if child not in children:continue
                matrix=source_matrix(row.get("matrix",{}))
                hits.append({"source_id":child,"source_default_frame":1,"depth":int(row["depth"]),"name":row.get("name"),"matrix":matrix,"rect":transform_rect(hit_shapes[str(child)]["rect"],matrix)})
            if hits:active[str(frame)]=hits
        timelines[str(parent)]={"space":f"source sprite{parent} local before outer actor/root matrix","frame_count":len(timeline),"active_by_source_frame":active,
                                "inactive_source_frames":"All source frames absent from active_by_source_frame; do not keep a previous hit shape alive after removal.",
                                "note":"Geometry only. Frame scripts, target state, per-target counters, marker damage observers and source scheduling decide whether these shapes produce a hit."}
        if parent in(4433,4459,4483,4484):
            creation=[];source_frame=1
            for tag in symbols[parent].find("subTags"):
                if tag.get("type")=="ShowFrameTag":source_frame+=1
                if tag.get("type","").startswith("PlaceObject")and tag.get("characterId")=="1140":creation.append({"source_frame":source_frame,"depth":int(tag.get("depth")),"place_flag_move":tag.get("placeFlagMove")=="true"})
            timelines[str(parent)]["independent_child_clock"]={"source_id":1140,"placements":creation,"child_active_source_frames":[1,2],"child_empty_stop_source_frame":3,"note":"Parent display-list presence is not an always-live hit window. Source1140 has its own clock and source callbacks; parent4433/4484 can retain the empty child for13frames. Root observer15/35/25 timing remains a separate source lifecycle."}
        for folder in (SOURCES/"scripts").glob(f"DefineSprite_{parent}*"):
            if folder.name==f"DefineSprite_{parent}" or folder.name.startswith(f"DefineSprite_{parent}_"):
                for frame in active:provenance.extend(source_record(p) for p in (folder/f"frame_{frame}").rglob("*.as"))
    def shape_rect(ident):
        b=symbols[ident].find("shapeBounds")
        return [int(b.get("Xmin"))/20,int(b.get("Ymin"))/20,(int(b.get("Xmax"))-int(b.get("Xmin")))/20,(int(b.get("Ymax"))-int(b.get("Ymin")))/20]
    runner_parent=next(r for r in source_frames(symbols[1108])[1].values() if r.get("characterId")=="1107")
    runner_matrix=source_matrix(runner_parent.get("matrix",{}))
    wait={"runner":{"root_id":1108,"parent_frame":1,"child_id":1107,"shape_chain":[1107,1106,1105],"matrix":runner_matrix,"rect":transform_rect(shape_rect(1105),runner_matrix),"active_child_frames":[1,150],"note":"1107 whiten transforms affect color only; detection geometry stays constant."}}
    for key,parent in (("mine_right",613),("mine_left",603)):
        row=next(r for r in source_frames(symbols[parent])[23].values()if r.get("characterId")=="207");matrix=source_matrix(row.get("matrix",{}))
        wait[key]={"root_id":parent,"parent_frame":23,"child_id":207,"matrix":matrix,"alpha_mult":int(row["colorTransform"]["alphaMultTerm"]),"frames1_to229":{"shape_id":205,"rect":transform_rect(shape_rect(205),matrix)},"frame230":{"shape_id":206,"rect":transform_rect(shape_rect(206),matrix)},"note":"Transparent timer/detection remains hitTest-visible. Do not substitute explosion224 bounds."}
    catalog["source_geometry"]["act02_hit_windows"]={"source":"res/structure/game.xml; original source-frame display-list placements, default collision frame1 and shapeBounds including source strokes","matrix_order":["scaleX","rotateSkew0","rotateSkew1","scaleY","translateX_px","translateY_px"],"hit_shapes":hit_shapes,"timelines":timelines,"wait_detectors":wait,"outer_transforms":"Actor action atlas offsets do not transform collision metadata. Apply actual source parent chain, actor scale, direction and root position exactly once."}
    catalog["source_geometry"]["act02_hit_windows"]["independent_hit_clocks"]={"1140":{"active_source_frames":[1,2],"empty_stop_source_frame":3,"parent_source":3916,"parent_stop_frame":2,"note":"The parent holding2 does not keep the child collision active forever. Original callbacks may gotoStop2 on frozen/armored targets; preserve those conditions separately."}}
    proxy=next(r for r in source_frames(symbols[4030])[2].values()if r.get("characterId")=="4029")
    inner=next(r for r in source_frames(symbols[4029])[1].values()if r.get("characterId")=="1119")
    leaf=next(r for r in source_frames(symbols[1119])[1].values()if r.get("characterId")=="1118")
    matrices=[source_matrix(r.get("matrix",{}))for r in (proxy,inner,leaf)]
    rect=shape_rect(1118)
    for matrix in reversed(matrices):rect=transform_rect(rect,matrix)
    catalog["source_geometry"]["air_normal_proxy"]={"4030":{"source_chain":[4030,4029,1119,1118],"outer_source_frame":2,"proxy_source_frame":1,"proxy_depth":int(proxy["depth"]),"proxy_name":proxy.get("name"),"matrices_outer_to_inner":matrices,"rect_enemy_local":rect,"shape_bounds_twips":dict(symbols[1118].find("shapeBounds").attrib),"alpha_mult":int(inner["colorTransform"]["alphaMultTerm"]),"note":"Independent transparent normal-hit proxy named 속/행동몸빵; do not substitute visible 공중4028 or PNG alpha. Its outer2 placement replaces ground3898."}}
    gravity={};frozen_geometry={}
    for enemy in (4030,7176):
        placements={}
        for f,rows in source_frames(symbols[enemy]).items():
            r=next((r for r in rows.values()if r.get("name")=="중력몸빵"),None)
            if r is not None:
                matrix=source_matrix(r.get("matrix",{}));placements[str(f)]={"clip_id":int(r["characterId"]),"depth":int(r["depth"]),"matrix":matrix,"rect_enemy_local":transform_rect(shape_rect(1118),matrix),"alpha_mult":int(r["colorTransform"]["alphaMultTerm"])}
        gravity[str(enemy)]={"source_chain":[enemy,1119,1118],"source_name":"중력몸빵","shape_bounds_twips":dict(symbols[1118].find("shapeBounds").attrib),"placements_by_outer_source_frame":placements,"note":"Root child persists through recorded outer pages, including airborne2; independent of inner facing and visible body. Ground4393 calls object hitTest on this rectangle after enemy/root transforms. root_y>=ground_y is only an approximation, not this object-object test."}
    for enemy,inner_id,frame,body_id,shape_id in ((4030,3898,63,1119,1118),(7176,7170,110,7157,7156)):
        outer=next(r for r in source_frames(symbols[enemy])[1].values()if r.get("characterId")==str(inner_id))
        body=next(r for r in source_frames(symbols[inner_id])[frame].values()if r.get("name")=="얼음몸빵")
        chain=[source_matrix(r.get("matrix",{}))for r in (outer,body)];rect=shape_rect(shape_id)
        for matrix in reversed(chain):rect=transform_rect(rect,matrix)
        frozen_geometry[str(enemy)]={"source_chain":[enemy,inner_id,body_id,shape_id],"inner_source_frame":frame,"body_name":"얼음몸빵","body_depth":int(body["depth"]),"matrices_outer_to_inner":chain,"rect_enemy_local":rect,"shape_bounds_twips":dict(symbols[shape_id].find("shapeBounds").attrib),"alpha_mult":int(body["colorTransform"]["alphaMultTerm"]),"note":"Frozen-hit proxy is distinct from root gravity body and airborne normal proxy. Apply actual inner facing/root matrix when testing source targets."}
    catalog["source_geometry"]["enemy_gravity_body"]=gravity;catalog["source_geometry"]["enemy_frozen_body"]=frozen_geometry
    silver=[]
    for f,rows in source_frames(symbols[4021]).items():
        for r in rows.values():
            if r.get("characterId")!="3991":continue
            color=r.get("colorTransform",{});assert int(color.get("alphaMultTerm",256))==0 and int(color.get("alphaAddTerm",0))==0
            silver.append({"parent_source_frame":f,"depth":int(r["depth"]),"matrix":source_matrix(r.get("matrix",{})),"alpha_mult":0,"alpha_add":0})
    assert [r["parent_source_frame"]for r in silver]==list(range(12,19))
    catalog["source_geometry"].setdefault("enemy_status",{})["silver"]={"source_id":3991,"source_frame_count":1,"shape_id":3990,"shape_bounds_twips":dict(symbols[3990].find("shapeBounds").attrib),"shape_rect_local":shape_rect(3990),"shape_has_graphic":True,"shape_fill_alpha":199,"shape_stroke_alpha":255,"parent_id":4021,"placements_by_parent_source_frame":silver,"removed_parent_source_frame":19,"render_visible":False,"animation":None,"source_observer_damage":13,"source_observer":"DefineSprite_4021/frame_12/PlaceObject2_3991_2/CLIPACTIONRECORD onClipEvent(enterFrame)*.as","note":"The child has a real black rectangle, but its original parent placement has alphaMultTerm0 and no alphaAdd on every retained page12..18. No invisible status atlas is needed; rendering the bare child would add a graphic absent from the original."}
    provenance.extend(source_record(p)for p in(SOURCES/"scripts/DefineSprite_4021/frame_12").rglob("*.as"))
    for root_frame in (2,4,6,41):
        for folder in (SOURCES/"scripts"/f"frame_{root_frame}").glob("PlaceObject*_4393_*"):provenance.extend(source_record(p)for p in folder.rglob("*.as"))
    sources={r["path"]:r for r in catalog["sources"]};sources.update({r["path"]:r for r in provenance});catalog["sources"]=list(sources.values())
    CATALOG.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+"\n",encoding="utf-8");verify_catalog()
    print(json.dumps({"act02_collision_frames":{k:list(v["active_by_source_frame"])for k,v in timelines.items()}},ensure_ascii=False))


def hud_source_geometry(character_id: int = 0) -> dict:
    """Read selected original display lists; no PNG alpha is used as UI geometry."""
    controls={"a":4064,"s":4066,"d":4068,"f":4060,"g":4056,"h":4054,"q":4070,"w":4083,"e":4074,"r":4076,"t":4072,"y":4078,"v":4081}
    if character_id not in (0,1,2,3,4):raise ValueError("Unreviewed HUD character page")
    parent_frame=character_id+1
    if character_id==1:controls={"a":4121,"s":4123,"d":4125,"f":4128,"q":4130,"h":4133,"w":4136,"e":4138,"r":4140,"revenger":4142,"v":4144,"t":4147,"g":4149,"z":4157}
    if character_id==2:controls={"a":4176,"s":4178,"d":4182,"g":4185,"f":4189,"h":4191,"w":4193,"e":4197,"r":4200,"z":4201,"v":4202,"q":4206,"air_z":4229}
    if character_id==3:controls={"a":4234,"s":4238,"d":4242,"f":4246,"g":4251,"q":4255,"h":4259,"w":4263,"e":4266,"v":4267,"air_z":4229,"unknown":4268,"locked_weapon":4272,"locked_b":4276,"locked_master":4283,"locked_awakening":4288}
    if character_id==4:controls={"v":4291,"z":4292,"a":4296,"s":4300,"d":4304,"f":4308,"g":4312,"h":4316,"q":4318,"w":4322,"e":4326,"r":4330,"t":4334,"y":4337}
    field_ids=((4114,4119),(4173,4174),(4230,4231),(4289,4290),(4289,4290))[character_id]
    symbols=read_source_symbols({4391,4030,7176,*field_ids,*controls.values()})
    frames=source_frames;matrix=source_matrix
    bar=frames(symbols[4391])[parent_frame]
    skills={}
    for key,ident in controls.items():
        placement=next(v for v in bar.values() if v.get("characterId")==str(ident));pm=matrix(placement.get("matrix",{}))
        timeline=frames(symbols[ident]);morph=None;source_ratios={};morph_matrix=None
        for frame,state in timeline.items():
            for row in state.values():
                child=int(row.get("characterId",-1));path=SOURCES/f"morphshapes/{child}.svg"
                if path.exists():
                    if morph is None:morph=child;morph_matrix=matrix(row.get("matrix",{}))
                    if child==morph:source_ratios[str(frame)]=int(row.get("ratio",0))
        cooldown={"source_morph_id":morph,"matrix":morph_matrix,"ratio_by_source_frame":source_ratios,"ratio_denominator":65535,"definition":"Original morph vertices and ratio, not a replacement radial timer"}
        if morph is not None:
            svg=ET.parse(SOURCES/f"morphshapes/{morph}.svg").getroot();ns={"s":"http://www.w3.org/2000/svg"}
            path=svg.find(".//s:path",ns);anim=next((a for a in path if a.get("attributeName")=="d"),None)
            if anim is None:raise ValueError(f"Missing original cooldown path interpolation for {ident}/{morph}")
            shapes=anim.get("values").split(";")
            def points(text):
                if re.search(r"[A-Za-z]",re.sub(r"[MLZ]","",text)):
                    raise ValueError(f"Unsupported source cooldown path command for {ident}/{morph}: {text}")
                values=[float(v) for v in re.findall(r"[-+]?(?:\d*\.\d+|\d+)",text)]
                if len(values)%2 or len(values)<6:
                    raise ValueError(f"Invalid source cooldown polygon for {ident}/{morph}: {text}")
                return [values[i:i+2] for i in range(0,len(values),2)]
            fill_anim=next((a for a in path if a.get("attributeName")=="fill"),None)
            cooldown.update({"start_vertices":points(shapes[0]),"end_vertices":points(shapes[-1]),"fill":path.get("fill"),"fill_end":fill_anim.get("values").split(";")[-1] if fill_anim is not None else path.get("fill"),"alpha":float(path.get("fill-opacity",1)),"source":f"res/morphshapes/{morph}.svg"})
        skills[key]={"source_id":ident,"source_parent_id":4391,"source_parent_frame":parent_frame,"name":placement.get("name"),"depth":int(placement["depth"]),
                     "matrix":pm,"local_position":pm[4:6],"stage_position":[round(12.95+pm[4],6),round(57.1+pm[5],6)],
                     "source_frame_count":len(timeline),"cooldown":cooldown,"input_keys":["Z","A"] if key=="a"and character_id in(0,3) else ["Z"]if key in("revenger","air_z")else []if key.startswith("locked_")or key=="unknown"else[key.upper()],
                     "visible_slot":key!="v"if character_id==0 else key!="z"if character_id==1 else key not in ("z","v","air_z")if character_id==2 else int(placement.get("colorTransform",{}).get("alphaMultTerm",256))!=0}
    fields={}
    for key,ident in zip(("gold","clear_cubes"),field_ids):
        tag=symbols[ident];placement=next(v for v in bar.values() if v.get("characterId")==str(ident));pm=matrix(placement.get("matrix",{}))
        rect=tag.find("bounds");rect=tag.find("textBounds") if rect is None else rect
        fields[key]={"source_id":ident,"source_definition":dict(tag.attrib),"bounds_twips":dict(rect.attrib) if rect is not None else {},
                     "stage_position":[round(12.95+pm[4],6),round(57.1+pm[5],6)],"font_id":1557,"font_height_px":10,
                     "source_text_definition":f"res/texts/{ident}.txt","texture_contains_initial_value":False}
    enemy={}
    for ident in (4030,7176):
        placements=frames(symbols[ident])[1]
        enemy[str(ident)]={str(child):{"matrix":matrix(row.get("matrix",{})),"depth":int(row["depth"])} for row in placements.values() if (child:=int(row.get("characterId",-1))) in (3900,3902)}
    return {"source_stage_size":[550,400],"panel":{"texture":("hud_panel_ready","hud_panel_crt1_ready","hud_panel_crt2_ready","hud_panel_crt3_ready","hud_panel_crt4_ready")[character_id],"source_id":4391,"source_frame":parent_frame,"stage_position":[12.95,57.1],"source_depth":567,
                "removed_dynamic_ids":[*field_ids,4112,4118],"cooldown_morphs_separate":True,"note":"Original fifth page; all14 source slots; Y291 preparation and independent world completion; no CRT3 lock-slot assumptions." if character_id==4 else "Ready static art has icons/labels/frame only. Original Y begins cooldown after setup; draw its live overlay, do not treat the base texture as an enabled-state claim." if character_id==0 else "Default original second-page slots.4157 Z is offstage;4142 Z is hurt-only.4151/4155/4165/4172 stay locked under the default profile; static icons are not enabled-state claims." if character_id==1 else "Original fourth page. S is actor-input; A/Z share a slot; V/airZ/4268 are alpha0.4272/4276/4283/4288 remain locked by3841 defaults." if character_id==3 else "Original third page.4201 Z/4202 V/4229 air Z have alpha0;4209/4213/4221/4227 remain locked in fresh defaults. Availability is controlled by source rules, not icon presence."},
            "hp":{"texture":"hud_hp_fill","source_id":4398,"stage_position":[24.05,42.6],"source_depth":791,"scale_x":"hp/hpm","empty_source_frame":2},
            "mp":{"texture":"hud_mp_fill","source_id":4395,"stage_position":[23.9,54.05],"source_depth":789,"scale_x":"mp/mpm"},
            "skills":skills,"dynamic_fields":fields,"enemy_bars":enemy,"enemy_bar_textures":{"3900":"enemy_hp_frame","3902":"enemy_hp_fill"},
            "enemy_bar_rules":{"space":"outer actor root, sibling of inner/air sprites","follows_facing":False,"retained_outer_frames":{"4030":[1,2,3],"7176":[1,2]},"scale":"outer source stage scale; only fill has hp/hpm x ratio","hp_observer_order":["fill._xscale=hp*100/hpm","if hp>hpm set hp=hpm","if hp<=0 fill.gotoAndStop2 and inner death"],"empty_fill_frame":2,"frame_remains_after_death":True,"source":"frame41/PlaceObject3_4030_111 enterFrame_22 and _7; frame2/PlaceObject3_4030_222 enterFrame_23 and _7; frame6/PlaceObject3_7176_458 enterFrame_38 and _9","note":"Only inner and air sprites flip. No full-HP visibility suppression or bar-label flip found in these instances."},
            "training":{"instructions":{"texture":"training_instructions","stage_position":[281.95,68.15],"depth":793},"title":{"texture":"training_title","stage_position":[359.05,34.45],"depth":800,"source_id":8491,"source_root_frame":41,"parent_filters_baked":True,"source_filters":[{"type":"GLOWFILTER","rgba":[0,0,0,255],"blur":[5,5],"strength":10,"passes":1},{"type":"DROPSHADOWFILTER","rgba":[0,0,0,255],"blur":[5,5],"distance":5,"angle":.7853851318359375,"strength":1,"passes":1},{"type":"BEVELFILTER","shadow_rgba":[0,0,0,255],"highlight_rgba":[255,255,255,255],"blur":[24,24],"distance":5,"angle":.7853851318359375,"strength":1.0976562,"inner_shadow":True,"passes":1}]},
                        "restore":{"prefix":"training_restore_","stage_position":[441.95,108.5],"depth":2709,"source_id":8495},"storage":{"prefix":"training_storage_","stage_position":[441.95,79.75],"depth":2712,"source_id":8498},
                        "menu":{"texture":"hud_menu_up","stage_position":[514.55,102.75],"depth":2657,"source_id":6934}},
            "evidence":"Original XML effective display lists and per-source-frame morph ratios; original embedded font1557; no health, money, cube or combo values are baked into the HUD texture."}


def build_training_hud(keys=None):
    verify_catalog()
    catalog=json.loads(CATALOG.read_text(encoding="utf-8"));previous={r["path"]:r["sha256"] for r in catalog["outputs"]}
    specs={"hud_panel_ready":{"source_id":4391,"mode":"panel_ready","stage_position":[12.95,57.1]},
           "hud_hp_fill":{"source_id":4398},"hud_mp_fill":{"source_id":4395},"enemy_hp_frame":{"source_id":3900},"enemy_hp_fill":{"source_id":3902},
           "training_instructions":{"source_id":8490},"training_title":{"source_id":8491,"mode":"root41","source_root_frame":41,"source_depth":800,"parent_filters_baked":True},"hud_menu_up":{"source_id":6934}}
    for name,ident in (("restore",8495),("storage",8498)):
        for state in ("up","over","down"):specs[f"training_{name}_{state}"]={"source_id":ident,"mode":"button_"+state,"button_state":state}
    if keys is not None:
        if any(key not in specs for key in keys):raise ValueError("Unknown selected training HUD component")
        specs={key:specs[key]for key in keys}
    geometry=hud_source_geometry()
    with tempfile.TemporaryDirectory(prefix="leba_training_hud_") as temp:
        images,bounds=render_ui_frames(Path(temp),specs)
        for key,definition in specs.items():catalog["textures"][key]=store_ui_texture(key,images[key],bounds[key],definition,previous)
    sources={r["path"]:r for r in catalog["sources"]}
    paths=[SOURCES/"structure/game.xml",SWF,SOURCES/"texts/4114.txt",SOURCES/"texts/4119.txt"]
    for skill in geometry["skills"].values():
        if skill["cooldown"].get("source"):paths.append(WORKSPACE/skill["cooldown"]["source"])
        paths.extend((SOURCES/f"scripts/DefineSprite_{skill['source_id']}").rglob("*.as"))
    for ident in (4391,4398,3902):paths.extend((SOURCES/f"scripts/DefineSprite_{ident}").rglob("*.as"))
    for path in paths:sources[path.relative_to(WORKSPACE).as_posix()]=source_record(path)
    catalog["sources"]=list(sources.values());catalog["source_geometry"]["battle_hud"]=geometry
    outputs={r["path"]:r for r in catalog["outputs"]}
    for key in specs:
        row=catalog["textures"][key]["output"];outputs[row["path"]]=row
    catalog["outputs"]=list(outputs.values());CATALOG.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    verify_catalog()
    print(json.dumps({"hud_textures":list(specs),"skill_slots":list(geometry["skills"]),"existing_outputs_unchanged":all(sha256(PROJECT/p)==h for p,h in previous.items())}))


def build_crt1_hud():
    verify_catalog();catalog=json.loads(CATALOG.read_text(encoding="utf-8"));previous={r["path"]:r["sha256"] for r in catalog["outputs"]}
    key="hud_panel_crt1_ready";spec={"source_id":4391,"mode":"panel_crt1_ready","source_frame":2,"stage_position":[12.95,57.1]}
    geometry=hud_source_geometry(1)
    with tempfile.TemporaryDirectory(prefix="leba_act02_crt1_hud_") as temp:
        images,bounds=render_ui_frames(Path(temp),{key:spec});catalog["textures"][key]=store_ui_texture(key,images[key],bounds[key],spec,previous)
    provenance=[source_record(SWF),source_record(SOURCES/"structure/game.xml"),source_record(SOURCES/"texts/4173.txt"),source_record(SOURCES/"texts/4174.txt")]
    for ident in (4121,4123,4125,4128,4130,4133,4136,4138,4140,4142,4144,4147,4149,4151,4155,4157,4165,4172):provenance.extend(source_record(p)for p in (SOURCES/f"scripts/DefineSprite_{ident}").rglob("*.as"))
    for skill in geometry["skills"].values():provenance.append(source_record(WORKSPACE/skill["cooldown"]["source"]))
    for folder,numbers in (("frame_41/PlaceObject3_4030_111",[7,22]),("frame_2/PlaceObject3_4030_222",[7,23]),("frame_6/PlaceObject3_7176_458",[9,38])):
        for n in numbers:provenance.append(source_record(SOURCES/f"scripts/{folder}/CLIPACTIONRECORD onClipEvent(enterFrame)_{n}.as"))
    catalog["source_geometry"]["battle_hud_crt1"]=geometry
    catalog["source_geometry"]["battle_hud"]["enemy_bar_rules"]=geometry["enemy_bar_rules"]
    sources={r["path"]:r for r in catalog["sources"]};sources.update({r["path"]:r for r in provenance});catalog["sources"]=list(sources.values())
    outputs={r["path"]:r for r in catalog["outputs"]};row=catalog["textures"][key]["output"];outputs[row["path"]]=row;catalog["outputs"]=list(outputs.values())
    CATALOG.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+"\n",encoding="utf-8");verify_catalog()


def build_crt3_hud():
    verify_catalog();catalog=json.loads(CATALOG.read_text(encoding="utf-8"));previous={r["path"]:r["sha256"] for r in catalog["outputs"]}
    key="hud_panel_crt3_ready";spec={"source_id":4391,"mode":"panel_crt3_ready","source_frame":4,"stage_position":[12.95,57.1]}
    geometry=hud_source_geometry(3)
    provenance=[source_record(SWF),source_record(SOURCES/"structure/game.xml"),source_record(SOURCES/"texts/4289.txt"),source_record(SOURCES/"texts/4290.txt")]
    for ident in (4234,4238,4242,4246,4251,4255,4259,4263,4266,4267,4268,4272,4276,4283,4288,4229):provenance.extend(source_record(p)for p in (SOURCES/f"scripts/DefineSprite_{ident}").rglob("*.as"))
    for skill in geometry["skills"].values():
        if skill["cooldown"].get("source"):provenance.append(source_record(WORKSPACE/skill["cooldown"]["source"]))
    for folder,numbers in (("frame_41/PlaceObject3_4030_111",[7,22]),("frame_2/PlaceObject3_4030_222",[7,23]),("frame_6/PlaceObject3_7176_458",[9,38])):
        for n in numbers:provenance.append(source_record(SOURCES/f"scripts/{folder}/CLIPACTIONRECORD onClipEvent(enterFrame)_{n}.as"))
    with tempfile.TemporaryDirectory(prefix="leba_act05_crt3_hud_") as temp:
        images,bounds=render_ui_frames(Path(temp),{key:spec});catalog["textures"][key]=store_ui_texture(key,images[key],bounds[key],spec,previous)
    catalog["source_geometry"]["battle_hud_crt3"]=geometry
    sources={r["path"]:r for r in catalog["sources"]};sources.update({r["path"]:r for r in provenance});catalog["sources"]=list(sources.values())
    outputs={r["path"]:r for r in catalog["outputs"]};row=catalog["textures"][key]["output"];outputs[row["path"]]=row;catalog["outputs"]=list(outputs.values())
    CATALOG.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+"\n",encoding="utf-8");verify_catalog()



def build_source_warehouse_crt3():
    """Bounded original2728 page5, not a relabeled CRT0 bitmap."""
    verify_catalog();catalog=json.loads(CATALOG.read_text(encoding="utf-8"));previous={r["path"]:r["sha256"]for r in catalog["outputs"]}
    ids={2728,2349,2401,2444,2502,2671,2672,2673,2639,2050,2635,2675,1557,2682,2687,2690,2691,2692,2693,2694,2695,2696}
    symbols=read_source_symbols(ids);state=source_frames(symbols[2728])[5]
    buttons={"warehouse_crt3_rings":2639}
    specs={"source_warehouse_crt3_weapons_panel":{"source_id":2728,"mode":"warehouse_static_5"}}
    for name,ident in buttons.items():
        for button_state in("up","over","down"):specs[f"source_{name}_{button_state}"]={"source_id":ident,"mode":"button_"+button_state}
    def row(child):
        r=next(r for r in state.values()if r.get("characterId")==str(child));return{"source_id":child,"depth":int(r["depth"]),"matrix":source_matrix(r.get("matrix",{}))}
    def field(child):
        e=symbols[child];b=e.find("bounds");return{**row(child),"source_variable":e.get("variableName"),"font_id":int(e.get("fontId")),"font_size_px":int(e.get("fontHeight"))/20,"align":int(e.get("align")),"bounds_local":[int(b.get(k))/20 for k in("Xmin","Ymin","Xmax","Ymax")],"source_initial_text":e.get("initialText"),"initial_text_rule":"Editor placeholder is not player progress; runtime reads current profile, unknown values stay explicitly unavailable."}
    ui=catalog["source_geometry"]["source_ui"];ui["buttons"].update(source_button_geometry(buttons,symbols))
    controls={name:{**row(ident),"button_key":name}for name,ident in(("warehouse_close",2050),("warehouse_weapons",2635),("warehouse_crt3_rings",2639))}
    ui["warehouse"]["pages"]["5"]={"source_frame":5,"texture":"source_warehouse_crt3_weapons_panel","buttons":controls,"fields":{name:field(child)for name,child in zip(("gold","clear_cubes","pama_stones"),(2671,2672,2673))},"source_title":"仓库","title_evidence":"Original page5 warehouse page5 original artwork;2675 is a slot decoration, not a replacement title; source art is rendered without replacing its title.","source_character_id":3,"render_rule":"Source2728 page5; all nine original CRT3 inventory selectors freeze at source1/empty. Four equipped-item group pages remain1. Live fields/popup and registered interactive buttons removed; unsupported categories retain original up art."}
    ui["warehouse"]["scope"]="Source2728 pages2(CRT0 weapon),3(CRT1 weapon),4(CRT2 weapon),5(CRT3 weapon),8(existing HP+10 ring workflow); unknown items stay empty/unavailable, no fabricated ownership or transaction."
    append_warehouse_control_metadata(catalog,symbols,pages=(5,))
    provenance=[source_record(SOURCES/"structure/game.xml")]
    for ident in ids|{2057}:
        for prefix in("DefineSprite","DefineButton2"):provenance.extend(source_record(p)for p in(SOURCES/"scripts"/f"{prefix}_{ident}").rglob("*.as"))
    publish_source_ui_parts(catalog,previous,specs,provenance)



def build_crt2_hud():
    verify_catalog();catalog=json.loads(CATALOG.read_text(encoding="utf-8"));previous={r["path"]:r["sha256"] for r in catalog["outputs"]}
    key="hud_panel_crt2_ready";spec={"source_id":4391,"mode":"panel_crt2_ready","source_frame":3,"stage_position":[12.95,57.1]}
    geometry=hud_source_geometry(2)
    provenance=[source_record(SWF),source_record(SOURCES/"structure/game.xml"),source_record(SOURCES/"texts/4230.txt"),source_record(SOURCES/"texts/4231.txt")]
    for ident in (4176,4178,4182,4185,4189,4191,4193,4197,4200,4201,4202,4206,4209,4213,4221,4227,4229):provenance.extend(source_record(p)for p in (SOURCES/f"scripts/DefineSprite_{ident}").rglob("*.as"))
    for skill in geometry["skills"].values():
        if skill["cooldown"].get("source"):provenance.append(source_record(WORKSPACE/skill["cooldown"]["source"]))
    for folder,numbers in (("frame_41/PlaceObject3_4030_111",[7,22]),("frame_2/PlaceObject3_4030_222",[7,23]),("frame_6/PlaceObject3_7176_458",[9,38])):
        for n in numbers:provenance.append(source_record(SOURCES/f"scripts/{folder}/CLIPACTIONRECORD onClipEvent(enterFrame)_{n}.as"))
    with tempfile.TemporaryDirectory(prefix="leba_act02_crt2_hud_") as temp:
        images,bounds=render_ui_frames(Path(temp),{key:spec});catalog["textures"][key]=store_ui_texture(key,images[key],bounds[key],spec,previous)
    catalog["source_geometry"]["battle_hud_crt2"]=geometry
    sources={r["path"]:r for r in catalog["sources"]};sources.update({r["path"]:r for r in provenance});catalog["sources"]=list(sources.values())
    outputs={r["path"]:r for r in catalog["outputs"]};row=catalog["textures"][key]["output"];outputs[row["path"]]=row;catalog["outputs"]=list(outputs.values())
    CATALOG.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+"\n",encoding="utf-8");verify_catalog()


def build_hud_feedback():
    """Combo/hover values and grenade stock read live state, never baked digits."""
    verify_catalog();catalog=json.loads(CATALOG.read_text(encoding="utf-8"));previous={r["path"]:r["sha256"] for r in catalog["outputs"]}
    specs={"hud_combo_label":{"source_id":7102,"mode":"placement_7108_2","baked_parent_scale_and_filters":True},
           "hud_hp_hover":{"source_id":7123,"mode":"button_over_static"},"hud_mp_hover":{"source_id":7129,"mode":"button_over_static"},
           "hud_grenade_cooldown":{"source_id":6894}}
    for key,parent,icon in (("f",6896,6895),("g",6900,6899),("h",6904,6903)):
        specs[f"hud_grenade_{key}_panel"]={"source_id":parent,"mode":"sprite_frame_2_static","source_frame":2,"dynamic_text_removed":True,"independent_icon_removed":True}
        specs[f"hud_grenade_{key}_icon"]={"source_id":icon,"mode":"grenade_icon","independent_flash_and_cooldown_removed":True}
    ids={7108,7102,7103,7104,7105,7106,7107,7123,7129,7117,7119,7121,7125,7126,7127,7128,7122,6917,6896,6900,6904,6895,6899,6903,6887,6898,6902,6892,6894}
    symbols=read_source_symbols(ids)
    def xml_value(x):return {"attributes":dict(x.attrib),"children":{c.tag:xml_value(c) for c in x}} if len(x) else dict(x.attrib)
    def text_field(ident):
        x=symbols[ident];b=x.find("bounds");col=x.find("textColor")
        return {"source_id":ident,"variable":x.get("variableName"),"font_id":int(x.get("fontId")),"font_height_px":int(x.get("fontHeight"))/20,"align":int(x.get("align")),
                "bounds_twips":{k:int(b.get(k))for k in ("Xmin","Xmax","Ymin","Ymax")},"color_rgba":[int(col.get(k))for k in ("red","green","blue","alpha")],"initial_text_is_placeholder":True}
    combo={str(frame):[{"source_id":int(r["characterId"]),"depth":int(r["depth"]),"matrix":source_matrix(r.get("matrix",{})),"dynamic":int(r["characterId"])in range(7103,7108)}for r in rows.values()]for frame,rows in source_frames(symbols[7108]).items()}
    filters={t.get("characterId"):[xml_value(c)for c in t.find("surfaceFilterList")]for t in symbols[7108].find("subTags")if t.get("characterId")and t.find("surfaceFilterList")is not None}
    feedback={"combo":{"source_id":7108,"stage_position":[425.85,125.05],"depth":4679,"source_frame_count":83,"source_control":{"1":"stop; com=0","83":"gotoAndStop1"},
                       "label_texture":"hud_combo_label","label_offset_px":[-6.55,-6.5],"label_parent_scale_baked":True,"frames":combo,"number_fields":{str(i):text_field(i)for i in range(7103,7108)},"original_filters":filters,
                       "note":"Numbers must read live com. Static label has original placement/filters baked. Dynamic text uses source font/matrices and listed bevel/glow; font alone does not reproduce those filters."},"hover":{},"grenades":{}}
    for name,ident,pos in (("hp",7123,[72.1,42.5]),("mp",7129,[72.15,53.95])):
        values=[]
        for r in symbols[ident].find("characters"):
            child=int(r.get("characterId"))
            if r.get("buttonStateOver")=="true" and child in symbols and symbols[child].get("type")=="DefineEditTextTag":
                values.append({**text_field(child),"matrix":source_matrix(dict(r.find("placeMatrix").attrib)),"depth":int(r.get("placeDepth"))})
        b=symbols[7122].find("shapeBounds")
        feedback["hover"][name]={"source_button_id":ident,"stage_position":pos,"texture":f"hud_{name}_hover","fields":values,"hit_rect":[int(b.get("Xmin"))/20,int(b.get("Ymin"))/20,(int(b.get("Xmax"))-int(b.get("Xmin")))/20,(int(b.get("Ymax"))-int(b.get("Ymin")))/20],"only_visible_on_hover_or_down":True}
    root=[742.15,284.6];hud=source_frames(symbols[6917])[1]
    for key,parent,icon,field,max_count in (("f",6896,6895,6887,5),("g",6900,6899,6898,4),("h",6904,6903,6902,3)):
        p=next(r for r in hud.values()if r.get("characterId")==str(parent));pm=source_matrix(p.get("matrix",{}));state=source_frames(symbols[parent])[2]
        ip=next(r for r in state.values()if r.get("characterId")==str(icon));fp=next(r for r in state.values()if r.get("characterId")==str(field));im=source_matrix(ip.get("matrix",{}));fm=source_matrix(fp.get("matrix",{}))
        active=source_frames(symbols[icon]);cool=next(r for r in active[2].values()if r.get("characterId")=="6894")
        feedback["grenades"][key]={"source_id":parent,"active_source_frame":2,"inactive_source_frame":1,"max_count_on_load":max_count,"root_hud_position":root,"parent_matrix":pm,"stage_position":[round(root[i]+pm[4+i],6)for i in range(2)],
                                   "panel_texture":f"hud_grenade_{key}_panel","icon_texture":f"hud_grenade_{key}_icon","icon_source_id":icon,"icon_matrix":im,"number_field":{**text_field(field),"matrix":fm},
                                   "static_count_prefix":{"zero_source_id":6888,"multiply_source_id":6889,"source_text":"0 and x are original static glyphs; the live single-digit stock follows the leading zero. They are not a baked initial stock value."},
                                   "independent_icon_clock":{"ready_source_frame":1,"cooldown_source_frames":[2,81],"next_source_frame":1,"frame_count":len(active),"cooldown_texture":"hud_grenade_cooldown","cooldown_matrix":source_matrix(cool.get("matrix",{})),"cooldown_alpha_mult":int(cool["colorTransform"]["alphaMultTerm"]),"flash_source_id":6892,"flash_animation":"hud_grenade_flash","flash_frames":10,"flash_source_placement":source_matrix(next(r for r in active[1].values()if r.get("characterId")=="6892").get("matrix",{}))},
                                   "note":"Panel source2 resets stock on entry. Active icon has a separate81-frame clock; source1 child6892 flashes10frames then stops. Static icon excludes flash/cooldown overlays."}
    # Finish source validation before creating any new output files.
    provenance=[source_record(SWF),source_record(SOURCES/"structure/game.xml")]
    for ident in (7108,6892,6895,6896,6899,6900,6903,6904):provenance.extend(source_record(p)for p in (SOURCES/f"scripts/DefineSprite_{ident}").rglob("*.as"))
    for ident in (7103,7104,7105,7106,7107,7117,7119,7121,7125,7126,7127,7128,6887,6888,6889,6898,6902):provenance.append(source_record(SOURCES/f"texts/{ident}.txt"))
    with tempfile.TemporaryDirectory(prefix="leba_act02_hud_feedback_") as temp:
        images,bounds=render_ui_frames(Path(temp),specs)
        for key,spec in specs.items():catalog["textures"][key]=store_ui_texture(key,images[key],bounds[key],spec,previous)
    for key,ident,filename in (("combo",1599,"1599_Headline R.ttf"),("numeric",2171,"2171_Gulim.ttf"),("inventory",3837,"3837_HYGothic-Extra.ttf")):
        record=copy_asset(Path("fonts")/filename,Path("fonts")/f"{key}.ttf",previous,provenance,ident);catalog["fonts"][key]=record["path"];catalog["font_records"][key]=record
    catalog["source_geometry"]["battle_hud_feedback"]=feedback
    sources={r["path"]:r for r in catalog["sources"]};sources.update({r["path"]:r for r in provenance});catalog["sources"]=list(sources.values())
    outputs={r["path"]:r for r in catalog["outputs"]}
    for key in specs:outputs[catalog["textures"][key]["output"]["path"]]=catalog["textures"][key]["output"]
    for record in catalog["font_records"].values():outputs[record["output"]["path"]]=record["output"]
    catalog["outputs"]=list(outputs.values());CATALOG.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+"\n",encoding="utf-8");verify_catalog()
    print(json.dumps({"feedback_textures":list(specs),"old_outputs_unchanged":sum(sha256(PROJECT/p)==h for p,h in previous.items())},ensure_ascii=False))


def build_training_scene():
    """Stage-A scene subset. Existing M1 outputs and unrelated catalog fields stay intact."""
    verify_catalog()
    catalog=json.loads(CATALOG.read_text(encoding="utf-8"))
    previous={row["path"]:row["sha256"] for row in catalog["outputs"]}
    specs={
        "training_map":{"source_id":8483,"mode":"root41","stage_position":[288.7,206.05],"stage_scale":[1.,1.],"source_depth":1,
                        "baked_color_transform":{"rgb_mult":233,"rgb_add":23,"alpha_mult":256,"denominator":256}},
        "training_ground":{"source_id":4393,"mode":"root41","stage_position":[305.85,360.15],"stage_scale":[1.,1.],"source_depth":781,
                           "baked_color_transform":{"rgb_mult":256,"rgb_add":0,"alpha_mult":15,"denominator":256}},
    }
    provenance=[source_record(SWF),source_record(SOURCES/"structure/game.xml"),source_record(SOURCES/"scripts/frame_41/DoAction.as")]
    with tempfile.TemporaryDirectory(prefix="leba_training_scene_") as temp:
        images,bounds=render_ui_frames(Path(temp),specs)
        for key,definition in specs.items():
            catalog["textures"][key]=store_ui_texture(key,images[key],bounds[key],definition,previous)
    music=copy_asset(Path("external/BGM/gate.mp3"),Path("audio/gate.mp3"),previous,provenance)
    catalog["audio"]["music"]["training"]=music["path"]
    catalog["audio_records"]["training"]=music
    catalog["stage_41_placements"]={
        "player":{"source_id":6732,"instance":"일","position":[132.4,314.9],"scale":[.6369171,.65245056],"depth":801,
                  "matrix":[.6369171,0,0,.65245056,132.4,314.9]},
        "enemies":[{"source_id":4030,"instance":"적","position":[412.1,361.],"scale":[.52941895,.51246643],"depth":111,
                    "matrix":[.52941895,0,0,.51246643,412.1,361.]}],
        "map":{"texture":"training_map","position":[288.7,206.05],"scale":[1.,1.],"depth":1},
        "ground":{"texture":"training_ground","position":[305.85,360.15],"scale":[1.,1.],"depth":781}}
    catalog["source_geometry"]["training"]={
        "source_root_frame":41,"source_stage_size":[550,400],
        "layers":[{"key":"training_map","depth":1},{"key":"wall","depth":3},{"key":"enemy","depth":111},{"key":"skill_bar","depth":567},{"key":"training_ground","depth":781},{"key":"player","depth":801}],
        "ground":{"source_id":4393,"source_shape_id":4392,"position":[305.85,360.15],"bounds_twips":[-7610,-10,7611,770],
                  "local_rect":[-380.5,-.5,761.05,39.],"stage_rect":[-74.65,359.65,761.05,39.],"alpha_mult":15,"alpha_denominator":256,
                  "note":"Original visible low-alpha ground is separate from background. Root player and enemy registration y differ; do not force both to this rect top."},
        "wall":{"source_id":7131,"position":[268.9,211.65],"depth":3,"alpha_mult":0,"polygons":[],"geometry_state":"empty sprite, no shape or nested placement"},
        "source":"res/structure/game.xml root41 effective display list; selected map8483/ground4393 independently rendered with their original parent color transforms"}
    sources={r["path"]:r for r in catalog["sources"]};sources.update({r["path"]:r for r in provenance});catalog["sources"]=list(sources.values())
    outputs={r["path"]:r for r in catalog["outputs"]}
    for key in specs:
        row=catalog["textures"][key]["output"];outputs[row["path"]]=row
    outputs[music["output"]["path"]]=music["output"];catalog["outputs"]=list(outputs.values())
    CATALOG.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    verify_catalog()
    print(json.dumps({"textures":list(specs),"music":music["path"],"stage":"stage_41_placements","existing_outputs_unchanged":all(sha256(PROJECT/p)==h for p,h in previous.items())}))


def append_act02_animations(keys: list[str]):
    """Import reviewed default action slices and exact source StartSound metadata."""
    verify_catalog()
    if any(key not in ACT02_ANIMATIONS for key in keys):raise ValueError("Unreviewed ACT02 animation key")
    catalog=json.loads(CATALOG.read_text(encoding="utf-8"));previous={r["path"]:r["sha256"] for r in catalog["outputs"]};original_outputs=previous.copy()
    provenance=[source_record(SWF),source_record(SOURCES/"structure/game.xml")]
    provenance += [source_record(SOURCES/f"scripts/DefineSprite_{ident}/frame_1/DoAction.as") for ident in FROZEN_SELECTORS]
    extra_ids={4717,4719,4545} if "crt0_skill_q" in keys else set()
    if any(k.startswith("sniper_")for k in keys):extra_ids.update({6813,6789,6795,6794,6800,6812})
    if any(k.startswith(("crt0_fire_","c4_"))for k in keys):extra_ids.update({1513,1503,1504,3917,3916,3915,4030,7176})
    if any(k.startswith("y_")for k in keys):extra_ids.update({4491,4465,4460,4486,4472,4480,4487,4415,4414})
    if any(k in ("enemy_frozen","boss7176_frozen")or k.startswith("status_")for k in keys):extra_ids.update({3893,3895,3898,7166,7167,7170,4030,7176,4021,3928,3939,3945,3922})
    symbols=read_source_symbols({6732,*[ACT02_ANIMATIONS[k][0] for k in keys],*[ACT02_ANIMATIONS[k][4] for k in keys if ACT02_ANIMATIONS[k][4] is not None],*extra_ids})
    actor_frames=source_frames(symbols[6732]);action_geometry={}
    with tempfile.TemporaryDirectory(prefix="leba_act02_actions_") as temp:
        profiles={}
        for page in sorted({AMMO_VARIANTS.get(key,1)for key in keys}):
            profiles[page]=render_default_player_frames(Path(temp)/f"ammo_{page}",[key for key in keys if AMMO_VARIANTS.get(key,1)==page],page)
        for key in keys:
            folders,bounds=profiles[AMMO_VARIANTS.get(key,1)]
            spec=ACT02_ANIMATIONS[key];ident,sequence,_,offset,parent,parent_frame=spec
            placement=next(v for v in source_frames(symbols[parent])[parent_frame].values() if v.get("characterId")==str(ident)) if parent is not None else {"matrix":{},"depth":None}
            matrix=source_matrix(placement.get("matrix",{}))
            outer=ACT02_OUTER_OFFSETS.get(key,[0.,0.])
            total_offset=[round(matrix[4+i]+outer[i],6) for i in range(2)]
            expected_scale=PARENT_SCALES.get(key,[1.,1.])
            if matrix[:4]!=[expected_scale[0],0.,0.,expected_scale[1]] or total_offset!=offset:
                raise ValueError(f"Reviewed action parent transform changed: {key}/{matrix}")
            catalog["animations"][key]=build_animation(key,spec,bounds,previous,provenance,folders[ident])
            if key.startswith(("summon_","crt0_runner_","hud_","sniper_","crt0_fire_","c4_","y_")):
                catalog["animations"][key]["render_profile"]="act02_source_component"
            if key in AMMO_VARIANTS:
                catalog["animations"][key]["render_profile"]="projectile_ammo_variant"
                catalog["animations"][key]["selector_pages"]={"541":AMMO_VARIANTS[key],"542":1}
            action_geometry[key]={"source_sprite_id":ident,"source_parent_id":parent,"source_parent_frame":parent_frame,"source_frames":sequence,
                                  "parent_matrix":matrix,"parent_depth":int(placement["depth"]) if placement["depth"] is not None else None,"parent_offset_in_atlas_pivot":True,
                                  "additional_outer_offset_px":outer,"total_baked_offset_px":offset,
                                  "note":"Source frames retain control nodes; runtime schedules goto/stop and independent actors. Do not apply the parent translation twice."}
            for root in (SOURCES/"scripts").glob(f"DefineSprite_{ident}*"):
                if root.name!=f"DefineSprite_{ident}" and not root.name.startswith(f"DefineSprite_{ident}_"):continue
                for frame in sequence:provenance.extend(source_record(p) for p in (root/f"frame_{frame}").rglob("*.as"))
            if parent is not None:
                for root in (SOURCES/"scripts").glob(f"DefineSprite_{parent}*"):
                    if root.name==f"DefineSprite_{parent}" or root.name.startswith(f"DefineSprite_{parent}_"):
                        provenance.extend(source_record(p) for p in (root/f"frame_{parent_frame}").rglob("*.as"))
            frame=1;sound_index=0
            for tag in symbols[ident].find("subTags"):
                if tag.get("type")=="ShowFrameTag":frame+=1
                if tag.get("type")!="StartSoundTag" or frame not in sequence:continue
                sound_index+=1;event_key=key if sound_index==1 else f"{key}_sound_{sound_index}"
                info=tag.find("soundInfo");sound_id=int(tag.get("soundId"))
                if info is None:raise ValueError(f"Missing StartSound info for {key}/{frame}")
                envelope=[{"sample":int(v.get("pos44")),"left":int(v.get("leftLevel")),"right":int(v.get("rightLevel"))} for v in info.findall("envelopeRecords/item")]
                event={"sprite_id":ident,"frame":frame,"sound_id":sound_id,"in_point_samples_44100":int(info.get("inPoint",0)),"envelope":envelope,
                       "source_sound_info":dict(info.attrib)}
                if info.get("hasOutPoint")=="true":event["out_point_samples_44100"]=int(info.get("outPoint"))
                if info.get("hasLoops")=="true":event["loop_count"]=int(info.get("loopCount"))
                record=copy_asset(Path("sounds")/f"{sound_id}.mp3",Path("audio")/f"{sound_id}.mp3",previous,provenance,sound_id)
                # A second route can legitimately reuse this newly imported sound.
                previous[record["output"]["path"]]=record["output"]["sha256"]
                catalog["audio"]["sfx"][event_key]=record["path"];catalog["audio_records"][event_key]=record;catalog["audio_events"][event_key]=event
    catalog["source_geometry"].setdefault("default_skill_actions",{}).update(action_geometry)
    catalog["source_geometry"]["atlas_draw_contract"]=ATLAS_DRAW_CONTRACT
    catalog["render_profiles"]["act02_source_component"]={"method":"Explicit selected source frames retain nested transforms and source registration; independent actor/timer/overlay clocks are documented separately. No source alpha was used to infer collision or trigger behavior."}
    if any(key in AMMO_VARIANTS for key in keys):
        catalog["render_profiles"]["projectile_ammo_variant"]={"method":"In-memory source541 selected original placement from page2(silver) or3(fire) is held;542 retains originalpage1. No tinting/repainting/resampling. Original projectile timeline, parent matrix and nested selected-page animation remain intact.","variant_pages":AMMO_VARIANTS}
        catalog["source_geometry"]["projectile_ammo_variants"]={"selector_id":541,"normal_page":1,"silver_page":2,"fire_page":3,"animation_pages":AMMO_VARIANTS,"load_selection":"1474/1473/1385 sequential if: zak==1 selects3, then eun==1 selects2; both flags therefore render silver.1472 zak==1 OR eun==1 selects2.","note":"Source load selects appearance once when constructed. Runtime damage/flags are separate; changing active flags later does not by itself prove a visual page update for an existing projectile."}
        for ident in (541,542):provenance.extend(source_record(p)for p in (SOURCES/f"scripts/DefineSprite_{ident}").rglob("*.as"))
    if any(key.startswith("ammo_fire_blast_")for key in keys):
        catalog["source_geometry"]["ammo_fire_blast"]={"source_id":731,"animations":{"a":"ammo_fire_blast_a","b":"ammo_fire_blast_b"},"selected_frames":[*range(1,11),*range(27,35)],"random_branch":"Source frame1 child730 enterFrame tests rand6<0.3 repeatedly; only first3 and final27 destinations are reachable through that chain. No correction of repeated conditions is applied.","routes":{"a":{"entry":3,"empty_stop":10},"b":{"entry":27,"empty_stop":34}},"collision_source":"act02_hit_windows.timelines.731; independent224 placements on3..4/7..8 or27..28/31..32","note":"Root attach transform and live gameplay flags are not baked into these images. Source frames1/2 are control/wait nodes; default CRT0 excludes weapon5/master routes35+."}
    if any(k in ("enemy_frozen","boss7176_frozen")or k.startswith("status_")for k in keys):
        def status_rows(ident,frame):
            return [{"source_id":int(r.get("characterId",-1)),"depth":int(r["depth"]),"name":r.get("name"),"matrix":source_matrix(r.get("matrix",{})),"alpha_mult":int(r.get("colorTransform",{}).get("alphaMultTerm",256))}for r in source_frames(symbols[ident])[frame].values()]
        frozen={}
        for enemy,inner,frame,container,body,key in ((4030,3898,63,3895,3893,"enemy_frozen"),(7176,7170,110,7167,7166,"boss7176_frozen")):
            frozen[str(enemy)]={"inner_source_id":inner,"inner_source_frame":frame,"inner_root_placement":next(r for r in status_rows(enemy,1)if r["source_id"]==inner),"inner_display_list":status_rows(inner,frame),"freeze_container_id":container,"container_frame_count":len(source_frames(symbols[container])),"body_id":body,"body_animation":key,"body_matrix":status_rows(container,1)[0]["matrix"],"body_initial_stop_frame":1,"body_reactions":{"2":{"through":4,"then":1},"5":{"through":7,"then":1}},"body_return_method":"gotoAndPlay1;1stop"if body==3893 else"gotoAndStop1","body_initial_offset_baked":True,"note":"Container lifetime and independent7-frame reaction body are separate. The source root observer may return the enemy before the full exported container duration; no150-frame repeated body atlas is imported."}
        status_parts=[r for r in status_rows(4021,1)if r["source_id"]in (3928,3939,3945)]
        for r in status_parts:
            r["animation"]={3928:"status_shock",3939:"status_stun",3945:"status_sniper_hit"}[r["source_id"]];r["initial_part_offset_baked"]=True
        catalog["source_geometry"]["enemy_status"]={**catalog["source_geometry"].get("enemy_status",{}),"frozen":frozen,"status_parent_id":4021,"enemy_parent_placements":{str(i):next(r for r in status_rows(i,1)if r["source_id"]==4021)for i in(4030,7176)},"parts":status_parts,
            "shock_stun":{"source_ids":[3928,3939],"ready_stop_source_frame":1,"visual_loop_source_frames":[2,10],"source10_destination":2,"counter_id":3922,"counter_source_frame_count":len(source_frames(symbols[3922])),"counter_created_at_source_frame":2,"counter_depth":2,"counter_alpha_mult":0,"counter_offset_px":[-1.45,-89.8],"note":"Counter load/t orw belongs to the source instance; do not reset it on every9-frame visual loop. Counter has no image."},
            "sniper_hit":{"source_id":3945,"ready_empty_stop_frame":1,"start_source_frame":2,"empty_source_frame":7,"end":"natural wrap to1/stop"},
            "note":"Frozen bodies replace the enemy inner visual; shock/stun/sniper FX are independent4021 children. Apply enemy root matrix and4021 parent matrix once, then part image whose local translation is already in pivot. Never use art alpha for gameplay state or collision."}
        for ident in (3893,3895,7166,7167,3928,3939,3945):provenance.extend(source_record(p)for p in (SOURCES/f"scripts/DefineSprite_{ident}").rglob("*.as"))
    if any(k in keys for k in ("crt0_skill_y","crt0_y_focus")):
        catalog["render_profiles"]["act02_y_empty_stops"]={"source_ids":[4806,4810],"empty_stop_frames":[29,16],"method":"Original empty final frames are held in an in-memory render copy through43 frames to prevent FFDec's non-scripted child loop within the reviewed Y parent1..40/focus1..38. Synthetic padding is never selected as a runtime source frame. Original nested order/placement remains baked."}
        for key in ("crt0_skill_y","crt0_y_focus"):
            if key in keys:catalog["animations"][key]["render_profile"]="act02_y_empty_stops"
        for ident in (4806,4810):provenance.extend(source_record(p)for p in (SOURCES/f"scripts/DefineSprite_{ident}").rglob("*.as"))
    if any(k in keys for k in ("crt0_skill_t","crt0_t_hold")):
        catalog["source_geometry"]["crt0_skill_t"]={"source_id":4760,"hold_source_frame":6,"hold_overlay":{"source_id":4759,"animation":"crt0_t_hold","depth":10,"local_offset_px":[-39.45,11.8],"baked_actor_offset_px":[3.95,11.65],"source_frame_count":16,"loop":True,"independent_clock":True},"note":"4759 placement removed from parent atlas. Start its independent16-frame loop when parent6 is constructed; final actor offset is already baked into hold atlas pivot."}
    if any(k.startswith("y_")for k in keys):
        def y_layers(ident,frame):
            return [{"source_id":int(r.get("characterId",-1)),"depth":int(r["depth"]),"name":r.get("name"),"matrix":source_matrix(r.get("matrix",{})),"alpha_mult":int(r.get("colorTransform",{}).get("alphaMultTerm",256))}for r in source_frames(symbols[ident])[frame].values()]
        y_groups={"normal":{"parent_id":4460,"parent_frame":1,"container_id":4465,"container_frame":1},"walk":{"parent_id":4465,"parent_frame":2,"container_id":4465,"container_frames":[2,3]},"focus":{"parent_id":4486,"parent_frame":1,"container_id":4486,"container_frame":1}}
        for name,group in y_groups.items():
            group["parts"]=y_layers(group["parent_id"],group["parent_frame"])
            for part in group["parts"]:
                key=next(k for k,spec in ACT02_ANIMATIONS.items()if k.startswith("y_"+name+"_")and spec[0]==part["source_id"])
                part.update({"animation":key,"frame_count":len(ACT02_ANIMATIONS[key][1]),"loop":True,"loop_to_source_frame":1,"terminal_frame_has_goto_or_stop":False,"loop_rule":"Natural timeline wrap; declared and actual frame counts match. No terminal control frame is swallowed.","initial_offset_baked":True})
        timer_starts=ACT02_ANIMATIONS["y_timer"][1];b=symbols[4414].find("shapeBounds")
        catalog["source_geometry"]["y_summon"]={"root_id":4491,"root_initial_matrices_by_stage":{"root_2":[1,0,0,1,-4.8,320.55],"root_4":[1,0,0,1,-4.8,320.55],"root_6":[1,0,0,1,-6.3,320.55],"training":[1,0,0,1,-10.3,314.6]},"root_pages":{str(f):y_layers(4491,f)for f in (2,3,4)},"groups":y_groups,
            "normal_container":{"source_id":4465,"source_frame_count":3,"source1":"stop with4460/normal group","source2_3":"walk group remains same placements; source3 naturally returns1. Original observers may repeatedly gotoPlay2; preserve native instance lifetime rather than inventing an unlimited static walking page."},
            "normal_timer":{"source_id":4480,"animation":"y_timer","frame_count":292,"invisible_frames":[1,160],"image_ranges":[{"from":f,"through":timer_starts[n+1]-1 if n+1<len(timer_starts) else 291,"image_source_frame":f}for n,f in enumerate(timer_starts)],"source292":"root4491.gotoAndStop4","initial_offset_baked":True},
            "focus_timer":{"source_id":4487,"frame_count":81,"transparent":True,"source81":"root4491.gotoAndStop4"},
            "spawn":{"source_id":4472,"animation":"y_spawn_fx","empty_stop_frame":7,"initial_offset_baked":False,"placement_source":"Every4472 in root_pages2/4 is a separate independent clock with its own exact matrix."},
            "exit":{"source_id":4490,"animation":"y_exit","last_source_frame":9,"source9":"root4491.gotoAndStop1","initial_offset_baked":True},
            "move_detector":{"source_id":4415,"shape_id":4414,"shape_bounds_twips":{k:int(b.get(k))for k in ("Xmin","Xmax","Ymin","Ymax")},"child_placements":y_layers(4415,1),"root_placement_source":"root_pages2 entry4415; transparent but hitTest-visible"},
            "note":"Twelve independent original loops; no composite all-gunners frame clock. Apply root follow/scale/direction and root page container matrix once; each group's part initial translation is already in its atlas pivot. Root initial stage positions are provenance, not permanently baked placement. Normal movement and focus replace their source display lists."}
        for ident in (4491,4465,4460,4486,4472,4480,4487):provenance.extend(source_record(p)for p in (SOURCES/f"scripts/DefineSprite_{ident}").rglob("*.as"))
    if any(k.startswith(("crt0_fire_","c4_"))for k in keys):
        floor_timeline=source_frames(symbols[1513]);floor_rows={};sparks={};seen_depths=set()
        for frame in range(1,181):
            rows=floor_timeline[frame]
            for r in rows.values():
                ident=int(r.get("characterId",-1))
                if ident==1503:floor_rows[str(frame)]={"matrix":source_matrix(r.get("matrix",{})),"alpha_mult":int(r.get("colorTransform",{}).get("alphaMultTerm",256))}
                if ident==1504 and r["depth"] not in seen_depths:
                    seen_depths.add(r["depth"]);sparks.setdefault(str(frame),[]).append({"depth":int(r["depth"]),"matrix":source_matrix(r.get("matrix",{}))})
        catalog["source_geometry"]["crt0_fire_floor"]={"root_id":1513,"source_frame_count":365,"default_parent_range":[1,180],"return_stop_frame":180,"return_destination":1,
            "animation":"crt0_fire_floor","child_id":1503,"child_default_range":[1,30],"child_source_frame_count":60,"child_goto":{"30":1},"child_placements_by_parent_source_frame":floor_rows,
            "child_sampled_loop_frames":[1,29],"sampled_loop_ticks":29,"control_source_frame":30,"leaf_id":1502,"leaf_recreated_on_child_source_frames":[1,16],"leaf_frame_by_sampled_child_frame":{str(f):f if f<=15 else f-15 for f in range(1,30)},
            "loop_evidence":"Original controlled persistent probe observes29→1 every29ticks and new1502 instances at1503 source1/16. FFDec26.2.1 DepthState independently records child time0 at source1/16; ratio15 on source16 does not affect rendered sprite pixels. Atlas source30 remains a control image, not an extra displayed tick.",
            "initial_parent_offset_baked":True,"parent_scale_baked":False,"spark":{"animation":"crt0_fire_spark","source_id":1504,"created_by_parent_source_frame":sparks,"empty_stop_frame":8,"matrix_baked":False},
            "note":"Root1513 keeps its independent default lifetime ending at source180. Child1503 samples1..29; control30 immediately returns1. Its child1502 resets at1/16, already correctly represented in the atlas. SourceSprite._draw applies recorded parent_scale and pivot applies the translation; only per-parent-frame alpha remains externally applied. Each spark uses its complete external rotated matrix. Weapon branches1513/181 and1503/31 are excluded."}
        charges={}
        for frame in (2,3,4):
            charges[str(frame)]=[{"depth":int(r["depth"]),"name":r.get("name"),"matrix":source_matrix(r.get("matrix",{}))}for r in source_frames(symbols[3917])[frame].values()if r.get("characterId")=="3916"]
        enemy_placements={}
        for ident in (4030,7176):
            enemy_placements[str(ident)]={str(frame):[{"depth":int(r["depth"]),"matrix":source_matrix(r.get("matrix",{}))}for r in rows.values()if r.get("characterId")=="3917"]for frame,rows in source_frames(symbols[ident]).items()}
        parts={}
        for frame in (1,2):
            for r in source_frames(symbols[3916])[frame].values():
                child=int(r.get("characterId",-1))
                parts[str(child)]={"parent_source_frame":frame,"depth":int(r["depth"]),"matrix":source_matrix(r.get("matrix",{})),"alpha_mult":int(r.get("colorTransform",{}).get("alphaMultTerm",256))}
        catalog["source_geometry"]["c4_attached"]={"container_id":3917,"count_source_pages":{"1":2,"2":3,"3":4},"charges_by_source_page":charges,"enemy_placements_by_source_frame":enemy_placements,
            "charge_id":3916,"charge_stop_pages":[1,2],"parts":parts,"charge_visuals":[{"animation":"c4_charge","source_id":3907,"loop_frames":[1,10],"depth":1},{"animation":"c4_charge_glow","source_id":3912,"loop_frames":[1,20],"depth":3,"alpha_mult":179}],
            "blink":{"animation":"c4_blink","source_id":3915,"ready_invisible_stop_frame":1,"loop_frames":[2,4],"frame4_goto":2,"depth":5},"blast":{"animation":"c4_blast","source_id":1138,"default_frames":[1,9],"empty_stop_frame":9,"depth":1},
            "hit":{"source_id":1140,"active_child_frames":[1,2],"empty_stop_frame":3,"depth":25},"initial_part_offsets_baked":True,"part_scales_baked":False,
            "note":"3917 pages2/3/4 define1/2/3 placements, not three static pictures. Each3916 has independent3907(10f) and3912(20f) loops and3915 blink. Add enemy/container/charge offsets once; part initial offset is already in atlas pivot. 3917f4 has only the original expression ㄴ; preserve caller gotoAndStop semantics. Detonation replaces all charge1 visuals with independent1138 and1140 at charge2."}
        for ident in (1513,1503,1504,3917,3916,3915,1138,1140,3907,3912):
            for folder in (SOURCES/"scripts").glob(f"DefineSprite_{ident}*"):
                if folder.name==f"DefineSprite_{ident}" or folder.name.startswith(f"DefineSprite_{ident}_"):
                    for p in folder.rglob("*.as"):
                        frame=int(p.relative_to(folder).parts[0].split("_")[1])
                        if (ident==1513 and frame>180) or (ident==1503 and frame>30) or (ident==1138 and frame>9):continue
                        provenance.append(source_record(p))
    if any(k.startswith("sniper_")for k in keys):
        parts={}
        for r in source_frames(symbols[6813])[6].values():
            ident=int(r.get("characterId",-1))
            if ident in (6789,6795,6800,6812):parts[str(ident)]={"depth":int(r["depth"]),"matrix":source_matrix(r.get("matrix",{}))}
        casings={};frame=1
        for t in symbols[6795].find("subTags"):
            if t.get("type")=="ShowFrameTag":frame+=1
            if t.get("characterId")=="6794" and frame<=7:
                casings.setdefault(str(frame),[]).append({"depth":int(t.get("depth")),"matrix":source_matrix(dict(t.find("matrix").attrib))})
        page_starts=ACT02_ANIMATIONS["sniper_timer"][1]
        catalog["source_geometry"]["sniper"]={**catalog["source_geometry"].get("sniper",{}),"source_id":6813,"root_matrix":[.63360596,0,0,.5973511,245.85,171.55],"root_source_frames":[2,4,6,41],"root_frame_count":12,"selected_root_frames":list(range(1,12)),"hold_source_frame":6,"parts":parts,
            "reticle":{"animation":"sniper_reticle","source_id":6789,"frame_count":15,"ready_stop_frame":1,"fire_frame":2,"firing_updates":"Source2 random6800 goto random(3)+2; ammo6795 nextFrame. Source15 random returns1; next natural frame is1/stop.","initial_parent_offset_baked":True},
            "ammo":{"animation":"sniper_ammo","source_id":6795,"selected_frames":list(range(1,8)),"source_frame_count":18,"parent_scale_baked":False,"initial_parent_offset_baked":True,"source_parent_scale":[.8200531,1],"casing_animation":"sniper_casing","casings_created_by_count_source_frame":casings,"casing_stop_empty_frame":18,"note":"Only default1..7 count pages; 6794 removed from static pages, spawn each new source placement once on count change."},
            "timer":{"animation":"sniper_timer","source_id":6812,"source_frame_count":265,"selected_image_source_frames":page_starts,"image_ranges":[{"from":v,"through":page_starts[n+1]-1 if n+1<len(page_starts) else 265,"image_source_frame":v}for n,v in enumerate(page_starts)],"on_source_frame265":"root6813.gotoAndPlay7","initial_parent_offset_baked":True,"note":"Independent265-frame clock;11 source image pages are not11 ticks or uniform one-second steps."},
            "random":{"source_id":6800,"selected_frames":[1,2,3,4],"rendered":False,"reason":"Identical shape6796 at source matrix offset[-1048.75,-472.2] remains wholly outside fixed550x400 stage. Random pages2/3/4 select source sound events; no extra white rectangle is imported."},
            "main_animation":"sniper_main","main_omitted_child_ids":[6789,6795,6800,6812],"note":"Root sniper matrix applies once to all parts. It is independent of the player's root/matrix. Reticle movement adds a local delta to its baked initial offset."}
        frame=1
        for tag in symbols[6800].find("subTags"):
            if tag.get("type")=="ShowFrameTag":frame+=1
            if tag.get("type")!="StartSoundTag":continue
            sid=int(tag.get("soundId"));info=tag.find("soundInfo");name=f"sniper_random_{frame}"
            event={"sprite_id":6800,"frame":frame,"sound_id":sid,"in_point_samples_44100":int(info.get("inPoint",0)),"envelope":[{"sample":int(v.get("pos44")),"left":int(v.get("leftLevel")),"right":int(v.get("rightLevel"))}for v in info.findall("envelopeRecords/item")],"source_sound_info":dict(info.attrib)}
            if info.get("hasOutPoint")=="true":event["out_point_samples_44100"]=int(info.get("outPoint"))
            record=copy_asset(Path("sounds")/f"{sid}.mp3",Path("audio")/f"{sid}.mp3",previous,provenance,sid);previous[record["output"]["path"]]=record["output"]["sha256"]
            catalog["audio_events"][name]=event;catalog["audio_records"][name]=record;catalog["audio"]["sfx"][name]=record["path"]
        for ident in (6813,6789,6795,6794,6800,6812):provenance.extend(source_record(p)for p in (SOURCES/f"scripts/DefineSprite_{ident}").rglob("*.as"))
    if "sniper_glass" in keys:
        catalog["source_geometry"]["sniper"]["glass"]={"animation":"sniper_glass","source_id":728,"linkage":"깨짐","source_frames":[1,30],"source30":"stop(); final parent placement alphaMultTerm0, inert clip remains until replacement/root teardown","host":"_root","as_depth":15000,"instance_name":"깨짐15000","root_scale":[1,1],"initial_parent_offset_baked":False,"spawn_position":"Copy current _root.깨짐도우미._x/_y exactly; no reticle/player/root6813 scale inheritance","helper_source_id":7111,"helper_root_placements_by_source_frame":selected_root_placements({7111},{2,4,6,41}),"helper_source6813_frame1_reset_px":[277,210],"input_source":"DefineSprite_6789/frame_1/PlaceObject2_6783_3 onClipEvent(keyDown) held T; load var i=15000 and no increment","replacement_rule":"Every accepted T keyDown attaches to same root ASdepth15000; replace the previous glass instance, not a pool of overlapping glass FX.","note":"6783 is the listener/reticle graphic, not the glass linkage.728 contains727/shape726 and its original30-frame alpha fade, all retained; no gameplay collision inferred."}
        catalog["source_geometry"]["sniper"]["unresolved_overlay"]={"reference":"_root.닐스나이핑","calls":{"6813/2":"gotoAndStop(2)","6813/11":"gotoAndPlay(3)"},"original_root_named_placements":0,"original_export_assets_links":0,"as_creation_or_assignment_found":False,"state":"Source calls exist, but full root XML display-list/ExportAssets scan and all exported AS finds no matching root instance or creation. The same name exists only under HUD4391 skill slots, a different object path.","rendered":False,"boundary":"Do not invent an overlay or redirect this root reference to the HUD slot. No native/dynamic dereference trace was added by this resource audit; unresolved reference is explicitly recorded."}
        for folder in (SOURCES/"scripts").glob("DefineSprite_728*"):provenance.extend(source_record(p)for p in folder.rglob("*.as"))
        provenance.extend(source_record(p)for p in(SOURCES/"scripts/frame_2/PlaceObject2_7111_4682").rglob("*.as"))
    if "hud_y_cutin" in keys:
        catalog["source_geometry"]["skill_cutin"]={"animation":"hud_y_cutin","source_id":6835,"parent_id":6917,"parent_source_frame":1,"parent_name":"컷신","parent_depth":1,"parent_matrix":[1,0,0,1,-771.15,16.6],"initial_parent_offset_baked":True,"root_placements_by_source_frame":selected_root_placements({6917},{2,4,6,9,41}),"trigger":{"actor_source_id":4812,"actor_source_frame":9,"operation":"_root.게임오버.컷신.gotoAndPlay(2)"},"source_frames":[1,33],"ready_invisible_stop_source_frame":1,"default_play_start":2,"terminal_control_source_frame":33,"terminal_operation":"gotoAndStop(1)","independent_clock":True,"default_child_id":6819,"default_child_frame_count":1,"note":"Only first/default cutin route. Other character routes34..193 are excluded. Apply only root6917 matrix externally: its6835 local[-771.15,16.6] is already in atlas pivot. Source33 is a control frame returning1 in the source scheduler, not an extra displayed hold. Re-trigger seeks existing child to2; failure6917 page2 removes the page1 child."}
        for f in(1,33):provenance.extend(source_record(p)for p in(SOURCES/f"scripts/DefineSprite_6835/frame_{f}").rglob("*.as"))
        provenance.extend(source_record(p)for p in(SOURCES/"scripts/DefineSprite_4812/frame_9").rglob("*.as"))
    if any(k.startswith(("summon_","crt0_runner_")) for k in keys):
        catalog["source_geometry"]["default_summons"]={
            "runner":{"root_id":1108,"root_scale":[1,1],"spawn":"Root attach at player root x/y; does not inherit player scale","wait_parent_frame":1,"wait_child_id":1107,"wait_animation":"crt0_runner_wait","wait_child_offset_px":[0,25],"wait_frame_image_mapping":"one image per independent source frame 1..150","wait_return":{"child_source_frame":150,"parent_destination_frame":10},"contact_parent_destination":2,"blast_animation":"crt0_runner_blast","blast_source_frames":[2,17],"empty_stop_parent_frame":17,"note":"1107 140..150 has real source RGB whitening. All150 small frames are retained to reuse the existing SourceSprite without a separate shader or alternate animation clock."},
            "mine":{"right_root_id":613,"left_root_id":603,"root_scale":[1,1],"spawn":"Root attach at player root x/y; select separate source613/603 by bug1; do not additionally flip source603","right_animation":"summon_mine_right","left_animation":"summon_mine_left","wait_parent_frame":23,"wait_child_id":207,"wait_child_duration":230,"contact_or_timeout_destination":24,"empty_stop_parent_frame":37,"timer_alpha_mult":0,"note":"Parent23 holds while child207 detection/age continues. 37 is empty stop, not a proven native removeMovieClip."}}
        for ident in (1106,1107,207):
            for root in (SOURCES/"scripts").glob(f"DefineSprite_{ident}*"):
                if root.name==f"DefineSprite_{ident}" or root.name.startswith(f"DefineSprite_{ident}_"):provenance.extend(source_record(p) for p in root.rglob("*.as"))
    if "crt0_skill_q" in keys:
        body=next(v for v in actor_frames[18].values() if v.get("characterId")=="4719")
        timer=next(v for v in source_frames(symbols[4718])[12].values() if v.get("characterId")=="4717")
        bounds=symbols[4545].find("shapeBounds");body_matrix=source_matrix(body.get("matrix",{}))
        catalog["source_geometry"]["crt0_skill_q"]={
            "source_id":4718,"source_control":{"9":"gotoAndPlay(12)","12":"stop()","13":"start fire-ammo timer4549 at2","21":"return actor1","22":"start silver-ammo timer4560 at2","30":"return actor1"},
            "choice_timeout":{"source_id":4717,"placed_source_frame":12,"frame_count":len(source_frames(symbols[4717])),"matrix":source_matrix(timer.get("matrix",{})),"alpha_mult":int(timer["colorTransform"]["alphaMultTerm"]),"on_source_frame101":"actor action.gotoAndPlay(13)","independent_clock":True,"texture_required":False},
            "loading_overlay":{"animation":"crt0_q_loading","source_id":4711,"placed_source_frame":1,"removed_source_frame":13,"parent_depth":63,"local_offset_px":[4.8,-84.2],"baked_actor_offset_px":[1.8,-83.35],"independent_clock":True,"empty_stop_source_frame":19,"note":"Removed from crt0_skill_q atlas; continue while parent holds12. Actor-local offset is already in the overlay atlas pivot."},
            "body_track":{"source_id":4719,"parent_id":6732,"parent_frame":18,"matrix":body_matrix,"active_source_frames":[n for n,rows in source_frames(symbols[4719]).items() if rows],"stop_source_frame":19,
                          "shape_id":4545,"source_bounds_twips":{k:int(bounds.get(k)) for k in ("Xmin","Xmax","Ymin","Ymax")},
                          "rect":[int(bounds.get("Xmin"))/20+body_matrix[4],int(bounds.get("Ymin"))/20+body_matrix[5],(int(bounds.get("Xmax"))-int(bounds.get("Xmin")))/20,(int(bounds.get("Ymax"))-int(bounds.get("Ymin")))/20],"empty_frames":"19 onward, original removes shape and stops; independent of held parent12"},
            "source":"res/scripts/DefineSprite_4718; DefineSprite_4717/frame_101/DoAction.as; DefineSprite_4719/frame_19/DoAction.as and original XML"}
        for ident in (4717,4719,4549,4560):provenance.extend(source_record(p) for p in (SOURCES/f"scripts/DefineSprite_{ident}").rglob("*.as"))
    catalog["render_profiles"]["crt0_default_equipment"]["freeze_first_frame_ids"]=FROZEN_SELECTORS
    sources={r["path"]:r for r in catalog["sources"]};sources.update({r["path"]:r for r in provenance});catalog["sources"]=list(sources.values())
    outputs={r["path"]:r for r in catalog["outputs"]}
    for key in keys:outputs[catalog["animations"][key]["output"]["path"]]=catalog["animations"][key]["output"]
    for row in catalog["audio_records"].values():outputs[row["output"]["path"]]=row["output"]
    catalog["outputs"]=list(outputs.values())
    CATALOG.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    verify_catalog()
    print(json.dumps({"added_or_refreshed_act02":keys,"source_geometry":"default_skill_actions","old_outputs_unchanged":sum(sha256(PROJECT/p)==h for p,h in original_outputs.items())},ensure_ascii=False))


def append_act03_animations(keys: list[str]):
    """Append explicitly reviewed ACT03 slices using the established atlas contract."""
    if "enemy7437_shot_marker" in keys and len(keys)>1:
        append_act03_animations([key for key in keys if key!="enemy7437_shot_marker"])
        append_act03_animations(["enemy7437_shot_marker"])
        return
    verify_catalog()
    if any(key not in ACT03_ANIMATIONS for key in keys):raise ValueError("Unreviewed ACT03 animation key")
    catalog=json.loads(CATALOG.read_text(encoding="utf-8"))
    previous={r["path"]:r["sha256"] for r in catalog["outputs"]};original=previous.copy()
    provenance=[source_record(SWF),source_record(SOURCES/"structure/game.xml")]
    provenance += [source_record(SOURCES/f"scripts/DefineSprite_{i}/frame_1/DoAction.as")for i in FROZEN_SELECTORS]
    ids={ACT03_ANIMATIONS[k][0] for k in keys}|{ACT03_ANIMATIONS[k][4]for k in keys if ACT03_ANIMATIONS[k][4] is not None}
    symbols=read_source_symbols(ids|{4592});geometry={}
    with tempfile.TemporaryDirectory(prefix="leba_act03_actions_")as temp:
        folders,bounds=render_default_player_frames(Path(temp),keys)
        for key in keys:
            spec=ACT03_ANIMATIONS[key];ident,sequence,_,offset,parent,parent_frame=spec
            placement=next(v for v in source_frames(symbols[parent])[parent_frame].values()if v.get("characterId")==str(ident))if parent is not None else{"matrix":{},"depth":None}
            matrix=source_matrix(placement.get("matrix",{}));scale=PARENT_SCALES.get(key,[1.,1.])
            expected_basis=ACT03_BAKED_BASIS.get(key,[scale[0],0.,0.,scale[1]])
            if matrix[:4]!=expected_basis or matrix[4:]!=offset:raise ValueError(f"ACT03 unreviewed parent transform {key}: {matrix}, expected {offset}")
            catalog["animations"][key]=build_animation(key,spec,bounds,previous,provenance,folders[ident])
            catalog["animations"][key]["render_profile"]="act03_default_source"
            if ident in(4580,4589):
                source_p=next(r for r in source_frames(symbols[4592])[9].values()if r.get("characterId")==str(ident))
                baked=source_matrix(source_p.get("matrix",{}));baked[4:]=[0.,0.]
                raw=next(t for t in symbols[4592].find("subTags")if t.get("characterId")==str(ident))
                catalog["animations"][key].update({"baked_placement_matrix":baked,"baked_alpha_mult":int(source_p.get("colorTransform",{}).get("alphaMultTerm",256)),"baked_alpha_denominator":256,"baked_filters_xml":ET.tostring(raw.find("surfaceFilterList"),encoding="unicode"),"render_profile":"act04_crt1_q_original_parent_filters","placement_contract":"Original4592f9 basis/CXFORM/filter baked; translation zero in wrapper. Runtime parent*authorPart*baked.inverse and authorAlpha/bakedAlpha; original part offset remains external."})
            geometry[key]={"source_sprite_id":ident,"source_parent_id":parent,"source_parent_frame":parent_frame,"source_frames":sequence,"parent_matrix":matrix,"parent_depth":int(placement["depth"])if placement["depth"]is not None else None,"parent_offset_in_atlas_pivot":True,"parent_basis_baked_in_pixels":key in ACT03_BAKED_BASIS,"evidence":"Original AS/XML default weapon0 armor1; control frames retained; runtime owns goto/stop and independent clocks."}
            if key in ("enemy_shot_marker","enemy7437_shot_marker"):
                catalog["source_geometry"].setdefault("enemy_shot_markers",{})[str(parent)]={"animation":key,"source_id":3887,"marker_source_id":parent,"marker_source_frame":9,"matrix":matrix,"source_frames":[1,2,3,4],"empty_stop_frame":4,"damage_observed_frame":2,"basis_and_blur_baked":True,"offset_in_atlas_pivot":True,"filter":{"type":"BLURFILTER","blurX":13,"blurY":0,"passes":1},"runtime_transform":"Apply only enemy/air/marker ancestors. Shot local matrix basis/filter are baked in pixels and local translation in pivot; do not apply matrix again.","source":"DefineSprite_3887/frame_1,2,4/DoAction.as and marker source9 original PlaceObject3_3887."}
            for i in [ident]+([parent]if parent is not None else[]):
                for directory in (SOURCES/"scripts").glob(f"DefineSprite_{i}*"):
                    if directory.name==f"DefineSprite_{i}"or directory.name.startswith(f"DefineSprite_{i}_"):
                        provenance.extend(source_record(p)for p in directory.rglob("*.as"))
            frame=1;index=0
            for tag in symbols[ident].find("subTags"):
                if tag.get("type")=="ShowFrameTag":frame+=1
                if tag.get("type")!="StartSoundTag"or frame not in sequence:continue
                index+=1;audio_key=key if index==1 else f"{key}_sound_{index}";info=tag.find("soundInfo");sid=int(tag.get("soundId"))
                if info is None:raise ValueError(f"Missing source soundInfo {ident}/{frame}")
                event={"sprite_id":ident,"frame":frame,"sound_id":sid,"in_point_samples_44100":int(info.get("inPoint",0)),"envelope":[{"sample":int(v.get("pos44")),"left":int(v.get("leftLevel")),"right":int(v.get("rightLevel"))}for v in info.findall("envelopeRecords/item")],"source_sound_info":dict(info.attrib)}
                if info.get("hasOutPoint")=="true":event["out_point_samples_44100"]=int(info.get("outPoint"))
                if info.get("hasLoops")=="true":event["loop_count"]=int(info.get("loopCount"))
                record=copy_asset(Path("sounds")/f"{sid}.mp3",Path("audio")/f"{sid}.mp3",previous,provenance,sid)
                previous[record["output"]["path"]]=record["output"]["sha256"]
                catalog["audio"]["sfx"][audio_key]=record["path"];catalog["audio_records"][audio_key]=record;catalog["audio_events"][audio_key]=event
    if "crt1_q_buff_icon" in keys:
        p=next(r for r in source_frames(symbols[4592])[9].values()if r.get("characterId")=="4591")
        parts=catalog["source_geometry"]["act03_crt1_components"]["buff"]["parts"]
        parts[:]=[r for r in parts if r["source_id"]!=4591]
        parts.append({"source_id":4591,"depth":int(p["depth"]),"name":p.get("name"),"matrix":source_matrix(p.get("matrix",{})),"alpha_mult":256,"animation":"crt1_q_buff_icon","loop_count":1,"source_visible_range":[9,400],"evidence":"Original4592f9 depth6 static4591/4590 yellow icon, retained independently from the two animated filter parts."})
    catalog["source_geometry"].setdefault("act03_crt1_actions",{}).update(geometry)
    catalog["render_profiles"]["act03_default_source"]={"default_equipment":{"crt":1,"weapon":0,"armor":1,"master":0},"freeze_first_frame_ids":FROZEN_SELECTORS,"independent_children_removed":{"5636":[5635],"4954":[4935],"5137":[5128],"5141":[5128],"5881":[5854,5879]},"method":"Existing source matrix/pivot/RGBA atlas workflow; original files readonly. Selected source controls are metadata, not synthetic frames."}
    sources={r["path"]:r for r in catalog["sources"]};sources.update({r["path"]:r for r in provenance});catalog["sources"]=list(sources.values())
    outputs={r["path"]:r for r in catalog["outputs"]}
    for key in keys:outputs[catalog["animations"][key]["output"]["path"]]=catalog["animations"][key]["output"]
    for row in catalog["audio_records"].values():outputs[row["output"]["path"]]=row["output"]
    catalog["outputs"]=list(outputs.values());CATALOG.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    verify_catalog()
    changed=[p for p,h in original.items()if sha256(PROJECT/p)!=h]
    reviewed={catalog["animations"][key]["output"]["path"]for key in keys}
    if set(changed)-reviewed:raise ValueError(f"Unrelated ACT03 output changed: {changed}")
    print(json.dumps({"act03_added":keys,"old_outputs_unchanged":len(original)-len(changed),"reviewed_refreshed_outputs":changed},ensure_ascii=False))


def append_act04_animations(keys: list[str]):
    """Append explicitly reviewed ACT04 slices using the established atlas contract."""
    if "all" in keys:keys=list(ACT04_ANIMATIONS)
    normal=[key for key in keys if not key.endswith("_pren") and not key.startswith("crt2_pren_")]
    empowered=[key for key in keys if key not in normal]
    if normal and empowered:
        append_act04_animations(normal)
        append_act04_animations(empowered)
        return
    verify_catalog()
    if any(key not in ACT04_ANIMATIONS for key in keys):raise ValueError("Unreviewed ACT04 animation key")
    catalog=json.loads(CATALOG.read_text(encoding="utf-8"))
    previous={r["path"]:r["sha256"] for r in catalog["outputs"]};original=previous.copy()
    provenance=[source_record(SWF),source_record(SOURCES/"structure/game.xml")]
    provenance += [source_record(SOURCES/f"scripts/DefineSprite_{i}/frame_1/DoAction.as")for i in sorted(set(FROZEN_SELECTORS+ACT04_PREN_SELECTORS+list(ACT04_STATIC_SELECTORS)))]
    ids={ACT04_ANIMATIONS[k][0] for k in keys}|{ACT04_ANIMATIONS[k][4]for k in keys if ACT04_ANIMATIONS[k][4] is not None}
    symbols=read_source_symbols(ids);geometry={}
    with tempfile.TemporaryDirectory(prefix="leba_act04_actions_")as temp:
        folders,bounds=render_default_player_frames(Path(temp),keys,crt2_page=2 if empowered else 1)
        for key in keys:
            spec=ACT04_ANIMATIONS[key];ident,sequence,_,offset,parent,parent_frame=spec
            placement=next(v for v in source_frames(symbols[parent])[parent_frame].values()if v.get("characterId")==str(ident))if parent is not None else{"matrix":{},"depth":None}
            matrix=source_matrix(placement.get("matrix",{}));scale=PARENT_SCALES.get(key,[1.,1.])
            expected_basis=[scale[0],0.,0.,scale[1]]
            if matrix[:4]!=expected_basis or matrix[4:]!=offset:raise ValueError(f"ACT04 unreviewed parent transform {key}: {matrix}, expected {offset}")
            catalog["animations"][key]=build_animation(key,spec,bounds,previous,provenance,folders[ident])
            catalog["animations"][key]["render_profile"]="act04_pren_source" if empowered else "act04_default_source"
            catalog["animations"][key]["source_selector_page"]=2 if empowered else 1
            geometry[key]={"source_sprite_id":ident,"source_parent_id":parent,"source_parent_frame":parent_frame,"source_frames":sequence,"parent_matrix":matrix,"parent_depth":int(placement["depth"])if placement["depth"]is not None else None,"parent_offset_in_atlas_pivot":True,"parent_basis_baked_in_pixels":False,"evidence":"Original AS/XML default weapon0 armor1; control frames retained; runtime owns goto/stop and independent clocks."}
            for i in [ident]+([parent]if parent is not None else[]):
                for directory in (SOURCES/"scripts").glob(f"DefineSprite_{i}*"):
                    if directory.name==f"DefineSprite_{i}"or directory.name.startswith(f"DefineSprite_{i}_"):
                        provenance.extend(source_record(p)for p in directory.rglob("*.as"))
            frame=1;index=0
            for tag in symbols[ident].find("subTags"):
                if tag.get("type")=="ShowFrameTag":frame+=1
                if tag.get("type")!="StartSoundTag"or frame not in sequence:continue
                index+=1;audio_key=key if index==1 else f"{key}_sound_{index}";info=tag.find("soundInfo");sid=int(tag.get("soundId"))
                if info is None:raise ValueError(f"Missing source soundInfo {ident}/{frame}")
                event={"sprite_id":ident,"frame":frame,"sound_id":sid,"in_point_samples_44100":int(info.get("inPoint",0)),"envelope":[{"sample":int(v.get("pos44")),"left":int(v.get("leftLevel")),"right":int(v.get("rightLevel"))}for v in info.findall("envelopeRecords/item")],"source_sound_info":dict(info.attrib)}
                if info.get("hasOutPoint")=="true":event["out_point_samples_44100"]=int(info.get("outPoint"))
                if info.get("hasLoops")=="true":event["loop_count"]=int(info.get("loopCount"))
                record=copy_asset(Path("sounds")/f"{sid}.mp3",Path("audio")/f"{sid}.mp3",previous,provenance,sid)
                previous[record["output"]["path"]]=record["output"]["sha256"]
                catalog["audio"]["sfx"][audio_key]=record["path"];catalog["audio_records"][audio_key]=record;catalog["audio_events"][audio_key]=event
            catalog["source_geometry"].setdefault("act04_crt2_actions",{}).update(geometry)
            source_rows={r["path"]:r for r in catalog["sources"]};source_rows.update({r["path"]:r for r in provenance});catalog["sources"]=list(source_rows.values())
            output_rows={r["path"]:r for r in catalog["outputs"]}
            for done in geometry:
                record=catalog["animations"][done]["output"];output_rows[record["path"]]=record
            for record in catalog["audio_records"].values():output_rows[record["output"]["path"]]=record["output"]
            catalog["outputs"]=list(output_rows.values())
            CATALOG.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    catalog["source_geometry"].setdefault("act04_crt2_actions",{}).update(geometry)
    for page,profile in ((1,"act04_default_source"),(2,"act04_pren_source")):
        catalog["render_profiles"][profile]={"default_equipment":{"crt":2,"weapon":0,"armor":1,"master":0,"pren":page-1},"selector_pages":{**{str(i):page for i in ACT04_PREN_SELECTORS},**{str(i):p for i,p in ACT04_STATIC_SELECTORS.items()}},"independent_children_removed":{"5649":[5416,5417],"5619":[5618],"5618":[5617],"5313":[5289],"802":[633],"685":[665],"676":[665]},"method":"In-memory exact source selected pages. Frames, pivots, clocks and transforms are preserved; original SWF remains readonly."}
    catalog["source_geometry"]["act04_crt2_pren_variants"]=ACT04_PREN_VARIANTS
    sources={r["path"]:r for r in catalog["sources"]};sources.update({r["path"]:r for r in provenance});catalog["sources"]=list(sources.values())
    outputs={r["path"]:r for r in catalog["outputs"]}
    for key in keys:outputs[catalog["animations"][key]["output"]["path"]]=catalog["animations"][key]["output"]
    for row in catalog["audio_records"].values():outputs[row["output"]["path"]]=row["output"]
    catalog["outputs"]=list(outputs.values());CATALOG.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    verify_catalog()
    changed=[p for p,h in original.items()if sha256(PROJECT/p)!=h]
    reviewed={catalog["animations"][key]["output"]["path"]for key in keys}
    if set(changed)-reviewed:raise ValueError(f"Unrelated ACT04 output changed: {changed}")
    print(json.dumps({"act04_added":keys,"old_outputs_unchanged":len(original)-len(changed),"reviewed_refreshed_outputs":changed},ensure_ascii=False))


def append_act04_crt1_audio(character_id=1):
    """Only reviewed missing child-clock sounds; never fold them into host frame1."""
    verify_catalog();catalog=json.loads(CATALOG.read_text(encoding="utf-8"));previous={r["path"]:r["sha256"]for r in catalog["outputs"]}
    requested={"crt1_h_direction_child":(5115,2),"crt1_e_flash_child":(5156,2),"crt1_e_tail_child":(5069,11),"crt1_t_phase_hit":(5840,2),"crt1_t_air_container":(5879,1),"crt1_r_helper1":(6771,3),"crt1_r_helper2":(6760,3),"crt1_r_helper3":(6752,3)}
    if character_id==2:requested={"crt2_e_hit_child":(5511,2),"crt2_r_end_hit_child":(298,2),"crt2_v_hit_child":(5732,12),"crt2_r_air_hit_child":(5609,[2,5]),"crt2_f_burst_host":(1077,[1,3,5,7,9])}
    symbols=read_source_symbols({v[0]for v in requested.values()});provenance=[source_record(SOURCES/"structure/game.xml")]
    for key,(ident,selected_frame)in requested.items():
        frame=1;found=0;selected_frames=selected_frame if isinstance(selected_frame,list)else[selected_frame]
        for tag in symbols[ident].find("subTags"):
            if tag.get("type")=="ShowFrameTag":frame+=1
            if tag.get("type")!="StartSoundTag"or frame not in selected_frames:continue
            found+=1;info=tag.find("soundInfo");sid=int(tag.get("soundId"));alias=key if found==1 else key+f"_sound_{found}"
            event={"sprite_id":ident,"frame":frame,"sound_id":sid,"clock":"independent source child timeline, not actor parent timeline","in_point_samples_44100":int(info.get("inPoint",0)),"envelope":[{"sample":int(v.get("pos44")),"left":int(v.get("leftLevel")),"right":int(v.get("rightLevel"))}for v in info.findall("envelopeRecords/item")],"source_sound_info":dict(info.attrib)}
            if info.get("hasOutPoint")=="true":event["out_point_samples_44100"]=int(info.get("outPoint"))
            if info.get("hasLoops")=="true":event["loop_count"]=int(info.get("loopCount"))
            record=copy_asset(Path("sounds")/f"{sid}.mp3",Path("audio")/f"{sid}.mp3",previous,provenance,sid);previous[record["output"]["path"]]=record["output"]["sha256"]
            catalog["audio"]["sfx"][alias]=record["path"];catalog["audio_records"][alias]=record;catalog["audio_events"][alias]=event
        if found!=len(selected_frames):raise ValueError(f"Reviewed child sound count changed: {key}: {found}")
    sources={r["path"]:r for r in catalog["sources"]};sources.update({r["path"]:r for r in provenance});catalog["sources"]=list(sources.values())
    outputs={r["path"]:r for r in catalog["outputs"]}
    for key in requested:
        row=catalog["audio_records"][key]["output"];outputs[row["path"]]=row
    catalog["outputs"]=list(outputs.values());CATALOG.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+"\n",encoding="utf-8");verify_catalog()
    print(json.dumps({"source_child_audio":list(requested),"source_clock_preserved":True}))


def append_act04_geometry():
    """Original CRT2 actor/body/helper display lists; no PNG-derived collisions."""
    verify_catalog();catalog=json.loads(CATALOG.read_text(encoding="utf-8"));g=catalog["source_geometry"]
    shape_by_clip={414:413,439:299,524:523,653:652,858:857,1234:1232,4509:4508,5260:1303,5291:5290,5652:5651,651:650,649:648}
    selections={}
    for spec in ACT04_ANIMATIONS.values():selections.setdefault(spec[0],set()).update(spec[1])
    selections[803]=set(range(1,41));selections[1077]=set(range(1,25))
    body_ids={4546,4547,4673,4745,5470}
    extras={5601,5609,5616,5617,4021,4000,4003,4001,6732,4545,4689,6917,6835,4600,4601,4604,4599,5289,633,665,5416,5417,5618,803,802,1077,1076,574,971,685,676,1023,593}
    symbols=read_source_symbols({*selections,*shape_by_clip,*shape_by_clip.values(),*body_ids,*extras})
    def rect(i):
        b=symbols[i].find("shapeBounds");return[int(b.get("Xmin"))/20,int(b.get("Ymin"))/20,(int(b.get("Xmax"))-int(b.get("Xmin")))/20,(int(b.get("Ymax"))-int(b.get("Ymin")))/20]
    def tx(r,m):
        x,y,w,h=r;ps=[(m[0]*a+m[2]*b+m[4],m[1]*a+m[3]*b+m[5])for a,b in((x,y),(x+w,y),(x,y+h),(x+w,y+h))]
        xs=[v[0]for v in ps];ys=[v[1]for v in ps];return[round(min(xs),9),round(min(ys),9),round(max(xs)-min(xs),9),round(max(ys)-min(ys),9)]
    def rows(i,f):return[{"source_id":int(r.get("characterId",-1)),"depth":int(dep),"name":r.get("name"),"matrix":source_matrix(r.get("matrix",{})),"alpha_mult":int(r.get("colorTransform",{}).get("alphaMultTerm",256))}for dep,r in source_frames(symbols[i])[f].items()]
    def pick(i,f,c):return next(r for r in rows(i,f)if r["source_id"]==c)
    def track(i,c):return{str(f):[r for r in rows(i,f)if r["source_id"]==c]for f in source_frames(symbols[i])}
    def controls(i):
        result={"stop_frames":[],"goto_by_source_frame":{},"scripts":[]}
        for directory in(SOURCES/"scripts").glob(f"DefineSprite_{i}*"):
            if directory.name!=f"DefineSprite_{i}"and not directory.name.startswith(f"DefineSprite_{i}_"):continue
            for p in directory.glob("frame_*/DoAction.as"):
                f=int(p.parent.name.split("_")[1]);text=p.read_text(encoding="utf-8");result["scripts"].append(p.relative_to(WORKSPACE).as_posix())
                if re.search(r"(?<!\.)\bstop\s*\(",text):result["stop_frames"].append(f)
                result["goto_by_source_frame"][str(f)]=re.findall(r"(?<!\.)\bgotoAnd(?:Play|Stop)\s*\((\d+)\)",text)
        result["stop_frames"].sort();return result
    shapes={str(c):{"shape_id":sid,"rect":tx(rect(sid),pick(c,1,sid)["matrix"]),"shape_matrix":pick(c,1,sid)["matrix"],"shape_bounds_twips":dict(symbols[sid].find("shapeBounds").attrib)}for c,sid in shape_by_clip.items()}
    timelines={}
    for i,frames in selections.items():
        active={str(f):[{**r,"rect":tx(shapes[str(r["source_id"])]["rect"],r["matrix"])}for r in rows(i,f)if r["source_id"]in shape_by_clip]for f in sorted(frames)}
        active={f:rs for f,rs in active.items()if rs}
        if active:timelines[str(i)]={"frame_count":len(source_frames(symbols[i])),"active_by_source_frame":active,"space":"source action local; rect includes helper placement, actor action parent matrix remains external","inactive_source_frames":"Missing frames are empty, not carry-forward.","calibration":"Source presence/geometry only; observer and damage rules are not inferred from alpha."}
    g["act04_crt2_hit_windows"]={"hit_shapes":shapes,"timelines":timelines,"source":"res/structure/game.xml; only reviewed default source action ranges"}
    bodies={str(i):{"rects_by_source_frame":{str(f):[tx(rect(4545),r["matrix"])for r in rows(i,f)if r["source_id"]==4545]for f in source_frames(symbols[i])},"frame_count":len(source_frames(symbols[i])),"source_shape_id":4545,"empty_is_absent":True,**controls(i)}for i in body_ids}
    for body in bodies.values():
        if len(body["stop_frames"])==1:body["stop_source_frame"]=body["stop_frames"][0]
    parents={str(f):{name:next((r for r in rows(6732,f)if r["name"]==name),None)for name in("몸빵","중력몸빵")}for f in[*range(64,95),97,100,112]}
    g["act04_crt2_body"]={"parents":parents,"clips":bodies,"clock":"Each clip has its own source age. stop_frames are original DoAction controls; no implicit lifetime shared across different placements.","rect_space":"clips.rects_by_source_frame already includes inner shape4545 placement; DOES NOT include actor parents placement. Apply parent matrix once.","source":"6732 and4546/4547/4673/4745/5470 source shape4545"}
    fx=pick(6732,74,4689)
    def original_fx(frame):
        f=1
        for t in symbols[6732].find("subTags"):
            if t.get("type")=="ShowFrameTag":f+=1
            if f==frame and t.get("characterId")=="4689":return t
        raise ValueError(f"Missing4689 parent{frame}")
    original=original_fx(14);current=original_fx(74)
    if ET.tostring(original.find("surfaceFilterList"))!=ET.tostring(current.find("surfaceFilterList")):raise ValueError("CRT2 hit FX filter differs: requires separate derived atlas")
    if pick(6732,14,4689)["matrix"][:4]!=fx["matrix"][:4]:raise ValueError("CRT2 hit FX basis differs")
    g["player_hit_fx"]["crt_2"]={**g["player_hit_fx"]["crt_1"],"parent_frame":74,"offset_px":fx["matrix"][4:],"placement_twips":[round(v*20)for v in fx["matrix"][4:]],"source_filter_equivalence":"Original6732f14/f74 XML basis and filter compared equal; existing4689 atlas reused with exactCRT2 offset."}
    components={"jump":{"parent_id":6732,"parent_frame":97,"source_id":5649,"parent_matrix":pick(6732,97,5649)["matrix"],"parts":[{"source_id":i,"animation":key,"placements_by_source_frame":track(5649,i),"source_frame_count":13,"stop_source_frame":1,"loop_control_frame":13,"loop_destination":1,"offset_baked":False}for i,key in((5416,"crt2_jump_attack_right"),(5417,""))]},
        "r_air":{"source_id":5618,"animation":"crt2_r_air","placements_by_source_frame":track(5619,5618),"source_frame_count":7,"loop":"natural source timeline 7->1","offset_baked":False},
        "r_cutin":{"source_id":6835,"animation":"hud_crt2_r_cutin","trigger_host":5619,"trigger_frame":4,"entry":66,"end_control":97,"return":1,"placement":pick(6917,1,6835)},
        "timers":{str(i):{"source_id":i,"parent_placement":pick(6732,64,i),"frame_count":len(source_frames(symbols[i])),"controls":controls(i),"independent_clock":True,"display_lists":{str(f):rows(i,f)for f in source_frames(symbols[i])}}for i in(4600,4601,4604)},
        "f":{"source_id":803,"independent_child":{"source_id":802,"placements_by_source_frame":track(803,802),"stop_source_frame":2,"resume_trigger":{"child_id":633,"child_frame":23,"operation":"_parent.nextFrame()"},"animation":"crt2_f_charge","frame_count":36,"inner_charge":{"source_id":633,"animation":"crt2_f_charge_core","placements_by_source_frame":track(802,633)}},"spawned_child":{"source_id":1077,"attach_source_frame":23,"inner_id":1076,"inner_start_frame":2,"inner_stop_frame":21,"animation":"crt2_f_burst","placements_by_source_frame":track(1077,1076)}},
        "derived_spawns":{str(i):{"source_id":i,"frame_count":len(source_frames(symbols[i])),"controls":controls(i),"display_lists":{str(f):rows(i,f)for f in source_frames(symbols[i])}}for i in(574,971,685,676,1023,593,803,1077)},
        "calibration":"Static original display-list geometry and reviewed control scripts. Runtime scheduling is not certified by resource extraction."}
    cutin_roots=selected_root_placements({6917},{2,4,6,9,41})
    components["r_cutin"].update({"root_placements_by_source_frame":cutin_roots,"immediate_parent_translation_in_atlas_pivot":True,"initial_parent_offset_baked":True,"immediate_parent_id":6917,"immediate_child_id":6835,"external_matrix_contract":"Atlas includes source6835 immediate parent translation[-771.15,16.6]. Apply ONLY the selected source-root6917 matrix externally; do not add placement.matrix again or replace the original slide-in path with centering.","source_evidence":"Root game.xml effective6917 placements in2/4/6/9/41;6917 source1 child6835;5619 source4 gotoAndPlay66"})
    # Common CRT0 Y feedback also uses root6917. Preserve all existing authored
    # source entries and add only the previously missing, confirmed root9 branch.
    g["skill_cutin"]["root_placements_by_source_frame"]["9"]=cutin_roots["9"]
    components["r_air"].update({"foreground_animation":"crt2_r_air","removed_subtree_id":5617,"removed_subtree_placement":pick(5618,1,5617),"removed_subtree_placements_by_source_frame":track(5618,5617),"parts":[{**pick(5617,1,i),"animation":key,"frame_count":count,"loop":"natural","offset_baked":False}for i,key,count in((5601,"crt2_r_air_back",1),(5609,"crt2_r_air_hit",6),(5616,"crt2_r_air_front",6))],"draw_order":["crt2_r_air_back","crt2_r_air_hit","crt2_r_air_front","crt2_r_air"],"part_matrix_contract":"R5619 child5618 placement * removed_subtree5617 placement * part placement; part atlas has zero baked parent offset. Foreground uses original5618 placement only.","clock_boundary":"5618 natural7, 5609 and5616 natural6 independently; do not reset child phase just because foreground wraps. Instance replacement still follows original timeline host behavior."})
    components["d_blood"]={"source_id":5289,"animation":"crt2_d_blood","placements_by_source_frame":track(5313,5289),"initial_stop":1,"trigger_source_frame":21,"empty_stop":40,"offset_baked":False}
    components["e_charge"]={"source_id":665,"animation":"crt2_e_charge","stop_source_frame":9,"placements_by_host":{str(i):track(i,665)for i in(685,676)},"offset_baked":False}
    components["h_aura"]={"source_id":4599,"animation":"crt2_h_aura","parent_timer":4600,"parent_active_frame":9,"placement":pick(4600,9,4599),"frame_count":35,"loop":"natural source timeline","offset_baked":False}
    components["timers"]["4601"].update({"animation":"crt2_g_timer","constant_frame_range":[9,399],"constant_visual_frame":9})
    components["timers"]["4604"].update({"animation":"crt2_lust_timer","constant_frame_range":[9,288],"constant_visual_frame":9})
    bleed_inner=pick(4003,1,4001);bleed_parent=pick(4021,20,4003)
    if any(rows(4003,f)!=rows(4003,1)for f in source_frames(symbols[4003])):raise ValueError("Bleed helper4003 geometry now varies by frame; update the explicit source contract")
    bleed_rect=tx(rect(4001),bleed_inner["matrix"])
    components["bleed_helper"]={"source_chain":[4021,4003,4001],"status_source_id":4021,"status_source_frame":20,"source_id":4003,"source_name":"피도우미","source_shape_id":4001,"shape_bounds_twips":{k:int(v)for k,v in symbols[4001].find("shapeBounds").attrib.items()if k in("Xmin","Xmax","Ymin","Ymax")},"shape_rect_local":rect(4001),"inner_placement":bleed_inner,"status_placement":bleed_parent,"rect_helper_local":bleed_rect,"rect_status_local":tx(bleed_rect,bleed_parent["matrix"]),"source_frame_count":140,"constant_source_frame_range":[1,140],"stop_source_frame":140,"alpha_mult":bleed_parent["alpha_mult"],"matrix_contract":"helper-local rect includes shape4001 placement once. For actor/status world collision compose enemy status4021 placement * status_placement, or use rect_status_local and apply only the enemy status4021 placement. Never substitute the enemy hurt_rect.","consumer":"CRT2 D5313 source28 helper5291 tests overlap against enemy status4021/frame20 피도우미4003","source":"res/structure/game.xml:4001/4003/4021;res/scripts/DefineSprite_4003/frame_140/DoAction.as","lifetime_boundary":"140 stops only helper4003; this does not prove status4021 automatically returns."}
    g["enemy_status"]["bleed"]={"container_source_id":4021,"container_frame":20,"body_source_id":4000,"body_animation":"enemy_bleed","body_placement":pick(4021,20,4000),"body_frame_count":12,"body_loop":"natural12->1;noAS","helper_source_id":4003,"helper_placement":bleed_parent,"helper_frame_count":140,"helper_stop_frame":140,"helper_shape_id":4001,"helper_rect":bleed_rect,"rect_space":"helper4003 local; parent4021 helper placement and enemy status placement remain external","lifetime_boundary":"Source4003f140 stops only itself. No automatic container exit is inferred; original instance observers own resets."}
    g["act04_crt2_components"]=components
    sources={r["path"]:r for r in catalog["sources"]};provenance=[source_record(SOURCES/"structure/game.xml")]
    for i in symbols:
        for directory in(SOURCES/"scripts").glob(f"DefineSprite_{i}*"):
            if directory.name==f"DefineSprite_{i}"or directory.name.startswith(f"DefineSprite_{i}_"):provenance.extend(source_record(p)for p in directory.rglob("*.as"))
    # The three knife FX use AS2 Sound.attachSound, not a StartSound tag.
    linkage=SOURCES/"symbolClass/symbols.csv"
    if '6;"대검"' not in linkage.read_text(encoding="utf-8"):raise ValueError("Default greatsword sound linkage changed")
    provenance.append(source_record(linkage));previous={r["path"]:r["sha256"]for r in catalog["outputs"]}
    sound_sources=list((SOURCES/"sounds").glob("6_*.mp3"))
    if len(sound_sources)!=1:raise ValueError("Expected the original named greatsword sound6 export")
    record=copy_asset(sound_sources[0].relative_to(SOURCES),Path("audio/6.mp3"),previous,provenance,6)
    alias="crt2_hit_slash_sound6";catalog["audio"]["sfx"][alias]=record["path"];catalog["audio_records"][alias]=record
    catalog["audio_events"][alias]={"sprite_id":1481,"host_sprite_ids":[1481,1489,1496],"frame":1,"sound_id":6,"in_point_samples_44100":0,"envelope":[],"source_sound_info":{},"dispatch":"AS2 new Sound.attachSound('대검');start() at each FX source1","condition":"crt2 and default weapon0 (블레이즈 !=5)","clock":"Each attached knifeFX creation, not the action input"}
    components["hit_slash"]={"animations":{"left":"crt2_hit_slash_left","horizontal":"crt2_hit_slash_horizontal","right":"crt2_hit_slash_right"},"source_ids":{"left":1481,"horizontal":1489,"right":1496},"source_frames":[1,2,3,4,5,6,7],"stop_source_frame":7,"audio":alias,"parent_id":None,"spawn_matrix":[1,0,0,1,"enemy._x","enemy._y"],"source_root_depths":{"horizontal":1,"left_helper":2,"right_helper":3},"continuous_overlap":"Original root observer repeats attachMovie at fixed category depth, replacing that instance.","source":"frame41/PlaceObject3_4030_111 load_3 and enterFrame_37/38/39; source1481/1489/1496 frame1 AS"}
    outputs={r["path"]:r for r in catalog["outputs"]};outputs[record["output"]["path"]]=record["output"];catalog["outputs"]=list(outputs.values())
    sources.update({r["path"]:r for r in provenance});catalog["sources"]=list(sources.values())
    CATALOG.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+"\n",encoding="utf-8");verify_catalog()


def append_act03_geometry():
    """Bounded default CRT1 and7437 source geometry; no image-derived hitboxes."""
    verify_catalog();catalog=json.loads(CATALOG.read_text(encoding="utf-8"));g=catalog["source_geometry"]
    shape_by_clip={1234:1232,439:299,4684:4683,858:857,4636:4635,651:650,5652:5651,653:652,5858:5857,6763:6762,4826:4825,1119:1118,7157:7156,7429:7428}
    requests={4851:{4684},4858:{439},4860:{439},6335:{1234},4928:{858,1234},4954:{1234,653},5114:{4636},5116:{4636},5122:{4636},5123:{4636,653},5158:{4636,653},5177:{4636},5679:{1234,5652,651},5881:{1234,5858},6771:{4636},6760:{4636},6752:{4636},6772:{6763},6764:{6763}}
    extras={6732,4546,4547,4673,4745,6334,4545,5636,5635,4935,4940,5137,5141,5128,5142,5854,5879,5856,4592,4580,4589,6884,6835,6917,1384,618,725,542,7437,7427,7436,7424,7423,7422,4029,4021,3917,6772,6764,6753,7370,7430}
    symbols=read_source_symbols({*requests,*shape_by_clip,*shape_by_clip.values(),*extras})
    def rect(ident):
        b=symbols[ident].find("shapeBounds");return[int(b.get("Xmin"))/20,int(b.get("Ymin"))/20,(int(b.get("Xmax"))-int(b.get("Xmin")))/20,(int(b.get("Ymax"))-int(b.get("Ymin")))/20]
    def tx(r,m):
        x,y,w,h=r;ps=[(m[0]*a+m[2]*b+m[4],m[1]*a+m[3]*b+m[5])for a,b in((x,y),(x+w,y),(x,y+h),(x+w,y+h))]
        xs=[p[0]for p in ps];ys=[p[1]for p in ps];return[round(min(xs),9),round(min(ys),9),round(max(xs)-min(xs),9),round(max(ys)-min(ys),9)]
    def rows(cid,frame):
        return[{"source_id":int(r.get("characterId",-1)),"depth":int(d),"name":r.get("name"),"matrix":source_matrix(r.get("matrix",{})),"alpha_mult":int(r.get("colorTransform",{}).get("alphaMultTerm",256))}for d,r in source_frames(symbols[cid])[frame].items()]
    def pick(cid,frame,child):return next(r for r in rows(cid,frame)if r["source_id"]==child)
    def track(cid,child):return{str(f):[r for r in rows(cid,f)if r["source_id"]==child]for f in source_frames(symbols[cid])}
    shapes={str(c):{"shape_id":s,"rect":tx(rect(s),pick(c,1,s)["matrix"]),"shape_bounds_twips":dict(symbols[s].find("shapeBounds").attrib)}for c,s in shape_by_clip.items()}
    timelines={}
    selections={}
    for spec in ACT03_ANIMATIONS.values():selections.setdefault(spec[0],set()).update(spec[1])
    for cid,children in requests.items():
        active={}
        for f in source_frames(symbols[cid]):
            if cid in selections and f not in selections[cid]:continue
            values=[]
            for row in rows(cid,f):
                if row["source_id"]in children:values.append({**row,"rect":tx(shapes[str(row["source_id"])]["rect"],row["matrix"])})
            if values:active[str(f)]=values
        timelines[str(cid)]={"space":f"source sprite{cid} local; multiply original actor action parent matrix once","frame_count":len(source_frames(symbols[cid])),"active_by_source_frame":active,"inactive_source_frames":"Missing frames are empty; do not retain preceding shapes.","calibration":"Presence and source geometry verified statically. Collision callback/marker contributions are separate; this is not a damage oracle."}
    g["act03_crt1_hit_windows"]={"hit_shapes":shapes,"timelines":timelines,"source":"res/structure/game.xml, original selected default pages and AS callbacks; no alpha-derived geometry"}
    bodies={}
    for cid in(4546,4547,4673,4745,6334):
        bodies[str(cid)]={"rects_by_source_frame":{str(f):[tx(rect(4545),r["matrix"])for r in rows(cid,f)if r["source_id"]==4545]for f in source_frames(symbols[cid])},"frame_count":len(source_frames(symbols[cid])),"source_shape_id":4545,"empty_is_absent":True}
    parents={}
    actor_parents=[30,31,32,33,*range(35,64),96,99,110,111,144,145]
    for f in actor_parents:
        parents[str(f)]={name:next((r for r in rows(6732,f)if r["name"]==name),None)for name in("몸빵","중력몸빵","건호크몸빵")}
    g["act03_crt1_body"]={"parents":parents,"clips":bodies,"clock":"Each source body clip has its own age and first-frame semantics; parentage change recreates only actual removed/replaced placements.","source":"6732 source placements and4546/4547/4673/4745/6334 source shape4545"}
    for name,cid in(("projectile_head",1384),("projectile_moving",618),("projectile_diagonal_two",725)):
        helper=[{"source_frame":int(f),"matrix":r["matrix"],"depth":r["depth"]}for f in source_frames(symbols[cid])for r in rows(cid,f)if r["source_id"]==542]
        g[name]={"source_id":cid,"source_child_id":542,"default_child_frame":1,"rect":g["projectile_diagonal"]["rect"],"space":"sprite542 before original frame matrix","source_bounds_twips":g["projectile_diagonal"]["source_bounds_twips"],"timeline_matrices":helper,"frame_count":len(source_frames(symbols[cid])),"empty_source_frames":[f for f in source_frames(symbols[cid])if not any(r["source_id"]==542 for r in rows(cid,f))],"stop_source_frame":{1384:10,618:16,725:11}[cid],"source":"res/scripts/DefineSprite_"+str(cid)+"_*/ and original XML"}
    components={"jump":{"parent_id":6732,"parent_frame":96,"sprite_id":5636,"parent_matrix":pick(6732,96,5636)["matrix"],"air_id":5635,"air_animation":"crt1_jump_air","air_overlay_by_frame":track(5636,5635),"air_local_offset_baked":False,"held_move":4,"fire_sub_frames":[2,3],"held_x_restart_frames":[1,5],"air_stop_frames":[1,6],"recoil_per_tick":-3,"movement_selector":{"source_id":4940,"forward_per_tick":3,"reverse_per_tick":-9},"projectile":"projectile_diagonal","projectile_local_spawn":{"x":0,"y":"230 + child._y"},"end_parent_frame":35,"end_parent_destination":30},
        "d_follow":{"sprite_id":4954,"parent_matrix":pick(6732,47,4954)["matrix"],"air_id":4935,"air_animation":"crt1_d_air","air_overlay_by_frame":track(4954,4935),"air_local_offset_baked":False,"fire_sub_frames":[2,3],"held_x_restart_frames":[1,5],"air_stop_frames":[1,5],"held_move":4,"recoil_per_tick":-3,"projectile":"projectile_diagonal_two","projectile_local_spawn":{"x":-50,"y":"160 + child._y"},"end_source_frame":31,"end_root_x_delta":10},
        "moving_fire":{"actor_parent":54,"parent_id":5142,"parent_matrix":pick(6732,54,5142)["matrix"],"idle":pick(5142,1,5137),"move":pick(5142,2,5141),"idle_animation":"crt1_w_idle","move_animation":"crt1_w_move","shot":pick(5137,1,5128),"shot_animation":"crt1_w_shot","shot_frames":[2,6],"ammo_consume_frames":[3,7],"shot_stop_frames":[1,5],"move_control_frame":17,"move_loop_destination":1,"ammo_source_id":6884,"ammo_source_start":2,"ammo_end_frame":22,"ammo_count":20,"ammo_hud_placement":pick(6917,1,6884),"ammo_animation":"hud_crt1_w_ammo","move_per_tick":6,"hold_keys":[87,88],"turn_key":90,"cancel_key":67,"projectile":"projectile_moving","spawn":{"root_space":True,"x_delta_times_facing":-90,"y_deltas":[-15,-10],"scale_y":.3}},
        "awakening":{"actor_parent":110,"sprite_id":5881,"parent_matrix":pick(6732,110,5881)["matrix"],"holds":{"25":{"next":26,"timer_id":5856,"timer_observed_frame":54,"visual":pick(5881,25,5854)},"43":{"next":44,"timer_id":5856,"timer_observed_frame":54,"visual":pick(5881,43,5854)},"66":{"next":67,"timer_id":5856,"timer_observed_frame":54,"visual":pick(5881,66,5879)}},"ground_parts":{"idle":pick(5854,1,5843),"move":pick(5854,2,5853),"fire":pick(5854,1,5845),"shell":pick(5854,1,5852)},"air_parts":rows(5879,1),"part_animations":{"5843":"crt1_t_hold_body","5853":"crt1_t_move_body","5845":"crt1_t_ground_fire","5852":"crt1_t_ground_shell","5875":"crt1_t_air_fire1","5876":"crt1_t_air_fire2","5877":"crt1_t_air_body"},"part_stop_frames":{"5852":4,"5877":5},"turn_allowed_parent_frames":[25,43],"move_allowed_parent_frames":[25,43,66],"move_per_tick":6,"normal_end_frame":96,"kill_branch":{"check_frame":94,"flag":"any enemy 스변==1","destination":97,"end_frame":120},"cutin":{"source_id":6835,"animation":"hud_crt1_t_cutin","trigger_source_frame":2,"entry":34,"end_control":65,"return":1,"placement":pick(6917,1,6835)}},
        "buff":{"source_id":4592,"parent_placement":pick(6732,30,4592),"start_source_frame":2,"active_start":9,"frame_count":407,"de_cleared_at":1,"edges_animation":"crt1_q_buff_edges","parts_active_frames":[9,400],"parts":[{**pick(4592,9,4580),"animation":"crt1_q_buff_ring","loop_count":12},{**pick(4592,9,4589),"animation":"crt1_q_buff_cloud","loop_count":14}],"part_offset_baked":False,"marker2_extra_damage":6,"shot_marker2_extra_damage":7},
        "gunhawks":{"stages":{"1":{"source_id":6772,"animation":"crt1_gunhawk1","entry":2,"end":46,"catch_source_frame":37,"catch_actor_parent":57,"catch_action":"r_catch1"},"2":{"source_id":6764,"animation":"crt1_gunhawk2","entry":2,"end":45,"catch_source_frame":36,"catch_actor_parent":58,"catch_action":"r_catch2"},"3":{"source_id":6753,"animation":"crt1_gunhawk3","entry":2,"end":49}},"root_placements":selected_root_placements({6772,6764,6753},{2,4,6,9,41}),"catch_detector_id":6763,"player_proxy_id":4826,"root_spawn_x":"player._x","source_y_retained":True,"source_scale_direction":"abs(root._xscale)*bug1","child_instances":{str(cid):{str(f):[r for r in rows(cid,f)if r["source_id"]in(6771,6760,6752)]for f in source_frames(symbols[cid])}for cid in(6772,6764,6753)}}}
    components["calibration"]="Original source composition/controls verified statically; no ACT03 original-runtime exact-damage oracle claimed. Independent children remain separate from parent atlases."
    g["act03_crt1_components"]=components
    g["battle_hud_crt1"]=hud_source_geometry(1)
    # New enemy shares real status/C4 containers but has distinct transforms,
    # gravity body and HP fill; preserve those source IDs and registrations.
    erows=rows(7437,1);outer_air=pick(7437,2,7436);mark=pick(7436,1,7422)
    g["air_hit_markers"]["7437"]={"animation":"enemy7437_air_hit_marker","source_id":7422,"parent_id":7436,"parent_frame":1,"offset_px":[outer_air["matrix"][4]+mark["matrix"][4],outer_air["matrix"][5]+mark["matrix"][5]],"scale":[mark["matrix"][0],mark["matrix"][3]],"removed_parent_frame":2,"source_frame_count":9}
    proxy=pick(7437,2,4029);proxy_inner=pick(4029,1,1119);proxy_rect=tx(tx(shapes["1119"]["rect"],proxy_inner["matrix"]),proxy["matrix"])
    air={"source_chain":[7437,4029,1119,1118],"matrices_outer_to_inner":[proxy["matrix"],proxy_inner["matrix"]],"rect_enemy_local":proxy_rect,"source_name":"속/행동몸빵","outer_source_frame":2}
    g["air_normal_proxy"]["7437"]=air;g["enemy_air_body"].setdefault("by_enemy",{})["7437"]={"rect":proxy_rect,"space":"enemy7437 outer local","source_id":1119}
    gravity={str(f):{**pick(7437,f,7429),"clip_id":7429,"rect_enemy_local":tx(shapes["7429"]["rect"],pick(7437,f,7429)["matrix"])}for f in source_frames(symbols[7437])}
    g["enemy_gravity_body"]["7437"]={"source_chain":[7437,7429,7428],"source_name":"중력몸빵","shape_bounds_twips":dict(symbols[7428].find("shapeBounds").attrib),"placements_by_outer_source_frame":gravity}
    inner=pick(7437,1,7427);ice=pick(7427,149,7424);ice_body=pick(7427,149,7157)
    g["enemy_status"]["frozen"]["7437"]={"inner_source_id":7427,"inner_source_frame":149,"inner_root_placement":inner,"inner_display_list":rows(7427,149),"freeze_container_id":7424,"container_frame_count":145,"body_id":7423,"body_animation":"enemy7437_frozen","body_matrix":pick(7424,1,7423)["matrix"],"body_initial_stop_frame":1,"body_reactions":{"2":{"through":4,"then":1},"5":{"through":7,"then":1}},"body_return_method":"gotoAndPlay1;1stop","body_initial_offset_baked":True}
    g["enemy_status"]["enemy_parent_placements"]["7437"]=pick(7437,1,4021)
    g["enemy_frozen_body"]["7437"]={"source_chain":[7437,7427,7157,7156],"parent_frame":149,"inner_matrix":inner["matrix"],"body_matrix":ice_body["matrix"],"rect_enemy_local":tx(shapes["7157"]["rect"],ice_body["matrix"]),"alpha_mult":0}
    g["c4_attached"]["enemy_placements_by_source_frame"]["7437"]={str(f):[{"depth":r["depth"],"matrix":r["matrix"]}for r in rows(7437,f)if r["source_id"]==3917]for f in source_frames(symbols[7437])}
    bar={str(r["source_id"]):{"matrix":r["matrix"],"depth":r["depth"],"role":"fill"if r["source_id"]==7430 else"frame","texture_key":"enemy7437_hp_fill"if r["source_id"]==7430 else"enemy_hp_frame"}for r in erows if r["source_id"]in(3900,7430)}
    for hud in("battle_hud","battle_hud_crt1"):g[hud]["enemy_bars"]["7437"]=bar;g[hud]["enemy_bar_rules"]["retained_outer_frames"]["7437"]=[1,2]
    provenance=[source_record(SOURCES/"structure/game.xml")]
    for ident in symbols:
        for folder in(SOURCES/"scripts").glob(f"DefineSprite_{ident}*"):
            if folder.name==f"DefineSprite_{ident}"or folder.name.startswith(f"DefineSprite_{ident}_"):provenance.extend(source_record(p)for p in folder.rglob("*.as"))
    for skill in g["battle_hud_crt1"]["skills"].values():
        if skill["cooldown"].get("source"):provenance.append(source_record(WORKSPACE/skill["cooldown"]["source"]))
    sources={r["path"]:r for r in catalog["sources"]};sources.update({r["path"]:r for r in provenance});catalog["sources"]=list(sources.values())
    CATALOG.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+"\n",encoding="utf-8");verify_catalog()


def append_act03_stage_assets():
    """Only root9 map and the enemy's actual HP fill, plus stable SFX aliases."""
    verify_catalog();catalog=json.loads(CATALOG.read_text(encoding="utf-8"));previous={r["path"]:r["sha256"]for r in catalog["outputs"]}
    specs={"map7370":{"source_id":7370,"mode":"sprite_frame_1","source_frame":1,"stage_position":[302.35,88.6],"stage_scale":[1.,1.],"source_depth":3,"note":"Root9 original placement has no color transform or filters; source7370 f1 stop. Default map page only."},"enemy7437_hp_fill":{"source_id":7430,"mode":"sprite_frame_1","source_frame":1,"note":"Actual7430 source fill, including its child3901 scale/offset; outer enemy matrix is metadata and applied once by runtime."}}
    with tempfile.TemporaryDirectory(prefix="leba_act03_stage_")as temp:
        images,bounds=render_ui_frames(Path(temp),specs)
        for key,definition in specs.items():catalog["textures"][key]=store_ui_texture(key,images[key],bounds[key],definition,previous)
    aliases={"enemy7437_swing":("enemy7437_ranged",169,54),"enemy7437_special_start":("enemy7437_special",6089,121),"enemy7437_special_hit":("enemy7437_special",6096,131),"enemy7437_death":("enemy7437_dead",5625,7)}
    for alias,(prefix,sid,frame)in aliases.items():
        old=next(k for k,e in catalog["audio_events"].items()if k.startswith(prefix)and e["sound_id"]==sid and e["frame"]==frame)
        for table in("audio_records","audio_events"):catalog[table][alias]=catalog[table][old].copy()
        catalog["audio"]["sfx"][alias]=catalog["audio"]["sfx"][old]
    provenance=[source_record(SWF),source_record(SOURCES/"structure/game.xml")]
    for cid in (7370,7430):
        provenance.extend(source_record(p)for p in(SOURCES/f"scripts/DefineSprite_{cid}").rglob("*.as"));provenance.append(source_record(sprite_dir(cid)/"1.png",cid,1))
    sources={r["path"]:r for r in catalog["sources"]};sources.update({r["path"]:r for r in provenance});catalog["sources"]=list(sources.values())
    outputs={r["path"]:r for r in catalog["outputs"]}
    for key in specs:r=catalog["textures"][key]["output"];outputs[r["path"]]=r
    catalog["outputs"]=list(outputs.values());CATALOG.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+"\n",encoding="utf-8");verify_catalog()


def refresh_animations(keys: list[str]):
    """Regenerate a reviewed bounded subset without rewriting unrelated outputs."""
    act04=[key for key in keys if key in ACT04_ANIMATIONS]
    if act04:
        append_act04_animations(act04)
        keys=[key for key in keys if key not in ACT04_ANIMATIONS]
    if not keys:return
    act03=[key for key in keys if key in ACT03_ANIMATIONS]
    if act03:
        append_act03_animations(act03)
        keys=[key for key in keys if key not in ACT03_ANIMATIONS]
    if not keys:return
    act02=[key for key in keys if key in ACT02_ANIMATIONS]
    if act02:
        append_act02_animations(act02)
        keys=[key for key in keys if key not in ACT02_ANIMATIONS]
        if not keys:return
    verify_catalog()
    if sha256(SWF)!=EXPECTED_SWF_SHA256:
        raise ValueError("Original SWF differs from the investigated version")
    catalog=json.loads(CATALOG.read_text(encoding="utf-8"))
    if any(key not in ANIMATIONS or key not in catalog["animations"] for key in keys):
        raise ValueError("Refresh only accepts existing registered animation keys")
    previous={row["path"]:row["sha256"] for row in catalog["outputs"]}
    provenance=[source_record(SOURCES/f"scripts/DefineSprite_{ident}/frame_1/DoAction.as") for ident in FROZEN_SELECTORS]
    with tempfile.TemporaryDirectory(prefix="leba_runtime_refresh_") as temp:
        folders,bounds=render_default_player_frames(Path(temp),keys)
        for key in keys:
            ident=ANIMATIONS[key][0]
            if ident not in folders:
                raise ValueError(f"No bounded source renderer for {key}")
            catalog["animations"][key]=build_animation(key,ANIMATIONS[key],bounds,previous,provenance,folders[ident])
    sources={row["path"]:row for row in catalog["sources"]}
    sources.update({row["path"]:row for row in provenance})
    for row in sources.values():
        if sha256(WORKSPACE/row["path"])!=row["sha256"]:
            raise ValueError(f"Source changed during refresh: {row['path']}")
    catalog["sources"]=list(sources.values())
    outputs={row["path"]:row for row in catalog["outputs"]}
    for key in keys:
        row=catalog["animations"][key]["output"]
        outputs[row["path"]]=row
    catalog["outputs"]=list(outputs.values())
    for profile in ("crt0_default_equipment","crt1_default_equipment"):
        catalog["render_profiles"][profile]["freeze_first_frame_ids"]=FROZEN_SELECTORS
    CATALOG.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    changed=[path for path,row in outputs.items() if previous[path]!=row["sha256"]]
    print(json.dumps({"refreshed_animations":keys,"changed_outputs":changed,"unchanged_output_count":len(outputs)-len(changed)},ensure_ascii=False))
    verify_catalog()


def verify_catalog():
    catalog=json.loads(CATALOG.read_text(encoding="utf-8"))
    for row in catalog["sources"]:
        path=(WORKSPACE/row["path"]).resolve()
        if not path.is_relative_to(WORKSPACE.resolve()) or sha256(path)!=row["sha256"]:
            raise ValueError(f"Source changed or invalid path: {row['path']}")
    for row in catalog["outputs"]:
        path=(PROJECT/row["path"]).resolve()
        if not path.is_relative_to(ASSETS.resolve()) or sha256(path)!=row["sha256"]:
            raise ValueError(f"Output changed or invalid path: {row['path']}")
    for key,texture in catalog.get("textures",{}).items():
        with Image.open(PROJECT/texture["path"].removeprefix("res://")) as image:
            x,y,w,h=texture.get("region",[0,0,image.width,image.height])
            if image.mode!="RGBA" or min(x,y)<0 or min(w,h)<=0 or x+w>image.width or y+h>image.height:
                raise ValueError(f"Invalid RGBA texture region: {key}")
            if not all(math.isfinite(n) for n in texture.get("pivot",[0,0])):
                raise ValueError(f"Invalid texture registration: {key}")
            if image.crop((x,y,x+w,y+h)).getchannel("A").getbbox() is None:
                raise ValueError(f"Required texture is empty: {key}")
    frame_count=0
    for key,animation in catalog["animations"].items():
        with Image.open(PROJECT/animation["texture"].removeprefix("res://")) as atlas:
            if atlas.mode!="RGBA":raise ValueError(f"No RGBA transparency: {key}")
            for frame in animation["frames"]:
                x,y,w,h=frame["region"]
                if min(x,y,w,h)<0 or x+w>atlas.width or y+h>atlas.height:
                    raise ValueError(f"Out-of-atlas frame: {key}/{frame['source_frame']}")
                if not all(math.isfinite(n) for n in frame["pivot"]):
                    raise ValueError(f"Invalid registration: {key}")
                if atlas.getpixel((x-1,y-1))!=(0,0,0,0):
                    raise ValueError(f"Atlas transparent gutter overwritten: {key}")
                frame_count+=1
        if animation["fps"]!=25:raise ValueError(f"Unexpected source animation timebase: {key}")
    print(json.dumps({"verified_source_hashes":len(catalog["sources"]),"verified_output_hashes":len(catalog["outputs"]),"verified_animation_frames":frame_count,"result":"PASS"}))

def act05_configuration():
    plan=json.loads((PROJECT/"data/act05_crt3_import.json").read_text(encoding="utf-8"))
    animations={k:tuple(v)for k,v in plan["ACT05_ANIMATIONS"].items()}
    ANIMATIONS.update(animations);FRAME_TRIM_KEYS.update(animations);PARENT_SCALES.update(plan["parent_scales"])
    return plan,animations


def append_act05_animations(keys):
    """CRT3-only derived copies. Per-frame weapon selector is rendered, never guessed from PNGs."""
    plan,animations=act05_configuration()
    if "all" in keys:keys=list(animations)
    if set(keys)-set(animations):raise ValueError("Unreviewed ACT05 key")
    verify_catalog();catalog=json.loads(CATALOG.read_text(encoding="utf8"))
    previous={r["path"]:r["sha256"]for r in catalog["outputs"]};original=previous.copy()
    provenance=[source_record(SWF),source_record(SOURCES/"structure/game.xml")]
    page_table=plan["weapon_shape_selector"]["render_page_by_source_frame"]
    geometry={}
    with contextlib.nullcontext(str(PROJECT/"artifacts/leba_act05_20261117/render_cache"))as temp:
        root=Path(temp);rendered={};all_bounds={}
        # Six source pages are independently rendered from the original SWF.
        # All images for a sprite are then padded to one exact source canvas.
        for page in range(1,7):
            chosen=[];saved={}
            for key in keys:
                spec=animations[key];frames=[f for f in spec[1]if int(page_table.get(key,{}).get(str(f),1))==page]
                if frames:
                    saved[key]=ANIMATIONS[key];ANIMATIONS[key]=(spec[0],frames,*spec[2:]);chosen.append(key)
            if not chosen:continue
            cache=root/str(page)/"render.json"
            signature=hashlib.sha256(json.dumps({"keys":{k:ANIMATIONS[k]for k in chosen},"selectors":plan["selector_pages"],"removed":plan["independent_children_removed"],"hold":plan.get("render_stop_hold",{}),"renderer":PLAYER_RENDERER},sort_keys=True).encode()).hexdigest()
            if cache.exists() and json.loads(cache.read_text(encoding="utf8")).get("signature")==signature:
                cached=json.loads(cache.read_text(encoding="utf8"));folders={int(k):Path(v)for k,v in cached["folders"].items()};bounds={int(k):v for k,v in cached["bounds"].items()}
            else:
                folders,bounds=render_default_player_frames(root/str(page),chosen,crt3_page=page)
                cache.write_text(json.dumps({"signature":signature,"folders":{k:str(v)for k,v in folders.items()},"bounds":bounds}),encoding="utf8")
            for key in chosen:
                spec=ANIMATIONS[key];ident=spec[0]
                for frame in spec[1]:rendered[(ident,frame)]=(folders[ident]/f"{frame}.png",bounds[ident]["filter_twips"])
                all_bounds.setdefault(ident,[]).append(bounds[ident]["filter_twips"])
                ANIMATIONS[key]=saved[key]
        normalized={};bounds={}
        for ident,values in all_bounds.items():
            # Pixel-aligned source origin preserves integer raster placement.
            union=[math.floor(min(v[0]for v in values)/20)*20,math.floor(min(v[1]for v in values)/20)*20,math.ceil(max(v[2]for v in values)/20)*20,math.ceil(max(v[3]for v in values)/20)*20]
            folder=root/"normalized"/str(ident);folder.mkdir(parents=True,exist_ok=True);normalized[ident]=folder
            for(i,f),(path,b)in rendered.items():
                if i!=ident:continue
                image=Image.open(path).convert("RGBA");canvas=Image.new("RGBA",((union[2]-union[0])//20,(union[3]-union[1])//20))
                canvas.alpha_composite(image,(round((b[0]-union[0])/20),round((b[1]-union[1])/20)));canvas.save(folder/f"{f}.png")
            bounds[ident]={"stroke_twips":union,"filter_twips":union}
        symbols=read_source_symbols({animations[k][0]for k in keys}|{animations[k][4]for k in keys if animations[k][4]is not None})
        for key in keys:
            spec=animations[key];ident,sequence,_,offset,parent,parent_frame=spec
            if parent is not None:
                r=next(r for r in source_frames(symbols[parent])[parent_frame].values()if r.get("characterId")==str(ident));matrix=source_matrix(r.get("matrix",{}))
                if matrix[4:]!=offset:raise ValueError(f"ACT05 parent offset changed: {key}")
            else:matrix=[1.,0.,0.,1.,0.,0.];r={}
            catalog["animations"][key]=build_animation(key,spec,bounds,previous,provenance,normalized[ident])
            for frame in catalog["animations"][key]["frames"]:
                number=int(frame["source_frame"]);b=rendered[(ident,number)][1];u=bounds[ident]["filter_twips"]
                dx=(b[0]-u[0])/20;dy=(b[1]-u[1])/20
                frame["pivot"][0]+=round(dx)-dx;frame["pivot"][1]+=round(dy)-dy
            catalog["animations"][key]["render_profile"]="act05_default_source"
            geometry[key]={"source_sprite_id":ident,"source_parent_id":parent,"source_parent_frame":parent_frame,"source_frames":sequence,"parent_matrix":matrix,"parent_depth":int(r.get("depth",0)),"parent_offset_in_atlas_pivot":True,"weapon74_pages":page_table.get(key,{})}
            for i in[ident]+([parent]if parent is not None else[]):
                for directory in(SOURCES/"scripts").glob(f"DefineSprite_{i}*"):
                    if directory.name==f"DefineSprite_{i}"or directory.name.startswith(f"DefineSprite_{i}_"):provenance.extend(source_record(p)for p in directory.rglob("*.as"))
            act05_import_sounds(catalog,previous,provenance,ident,sequence,key,symbols[ident])
            catalog["source_geometry"].setdefault("act05_crt3_actions",{}).update(geometry)
            act05_publish(catalog,provenance)
    catalog["source_geometry"].setdefault("act05_crt3_actions",{}).update(geometry)
    catalog["render_profiles"]["act05_default_source"]={"default_equipment":{"crt":3,"weapon":0,"armor":1,"master":0},"selector_pages":plan["selector_pages"],"weapon74_pages":page_table,"independent_children_removed":plan["independent_children_removed"],"method":"Source-selected page1 equipment; weapon74 selected per reviewed source frame. Derived in-memory copies only. Alpha-trim atlas retains source registration; independent objects are excluded and driven by their own clocks."}
    feedback=PROJECT/"data/act05_crt3_feedback.json"
    if feedback.exists() and "crt3_e_screen_flash"in catalog["animations"]:catalog["source_geometry"].setdefault("act05_crt3_components",{})["screen_feedback"]=json.loads(feedback.read_text(encoding="utf8"))
    act05_publish(catalog,provenance)
    reviewed={catalog["animations"][key]["output"]["path"]for key in keys}
    if any(sha256(PROJECT/p)!=h for p,h in original.items()if p not in reviewed):raise ValueError("ACT05 changed an unrelated output")
    print(json.dumps({"act05_imported":keys,"existing_outputs_unchanged":len(original)},ensure_ascii=False))


def act05_import_sounds(catalog,previous,provenance,ident,sequence,key,symbol=None):
    symbol=symbol if symbol is not None else read_source_symbols({ident})[ident]
    frame=1;index=0
    for tag in symbol.find("subTags"):
        if tag.get("type")=="ShowFrameTag":frame+=1
        if tag.get("type")!="StartSoundTag"or frame not in sequence:continue
        index+=1;alias=key if index==1 else f"{key}_sound_{index}";sid=int(tag.get("soundId"));info=tag.find("soundInfo")
        record=act05_sound_asset(sid,previous,provenance)
        event={"sprite_id":ident,"frame":frame,"sound_id":sid,"in_point_samples_44100":int(info.get("inPoint",0)),"envelope":[{"sample":int(v.get("pos44")),"left":int(v.get("leftLevel")),"right":int(v.get("rightLevel"))}for v in info.findall("envelopeRecords/item")],"source_sound_info":dict(info.attrib)}
        if info.get("hasOutPoint")=="true":event["out_point_samples_44100"]=int(info.get("outPoint"))
        if info.get("hasLoops")=="true":event["loop_count"]=int(info.get("loopCount"))
        catalog["audio"]["sfx"][alias]=record["path"];catalog["audio_records"][alias]=record;catalog["audio_events"][alias]=event


def append_act05_filtered():
    from render_act05_filtered import render_filtered
    plan,_=act05_configuration();verify_catalog();catalog=json.loads(CATALOG.read_text(encoding="utf8"))
    previous={r["path"]:r["sha256"]for r in catalog["outputs"]};provenance=[source_record(SWF),source_record(SOURCES/"structure/game.xml")]
    variants=plan["e_hit_parent_wrappers"]["variants"];specs={}
    for variant in variants:
        specs[variant["animation_key"]]={"source_id":6259,"parent_id":6276,"parent_source_frame":int(variant["parent_source_frame"]),"depth":int(variant["parent_depth"]),"frames":[1,2,3,4],"bake_basis":True}
    specs["crt3_w_subattack"]={"source_id":6166,"parent_id":6177,"parent_source_frame":6,"depth":1,"frames":list(range(1,15)),"bake_basis":False}
    with tempfile.TemporaryDirectory(prefix="leba_act05_filtered_")as temp:
        folders,bounds=render_filtered(Path(temp),specs)
        for key,render in specs.items():
            ident=render["source_id"];spec=(ident,render["frames"],False,[0,0],None,None);FRAME_TRIM_KEYS.add(key)
            animation=build_animation(key,spec,{ident:bounds[key]},previous,provenance,folders[key])
            basis=next((r["baked_placement_matrix"]for r in variants if r["animation_key"]==key),[1,0,0,1,0,0])
            animation.update({"baked_placement_matrix":basis,"baked_alpha_mult":256,"render_profile":"act05_original_parent_filtered","original_parent_id":render["parent_id"],"original_parent_frame":render["parent_source_frame"],"original_parent_depth":render["depth"],"matrix_contract":"Clone original placement/filter/CXFORM, remove translation. Runtime composes original parent then inverse baked basis exactly once."})
            catalog["animations"][key]=animation
    catalog["source_geometry"].setdefault("act05_crt3_components",{})["e_hit_variants"]={str(v["parent_depth"]):v["animation_key"]for v in variants}
    act05_publish(catalog,provenance)


def append_act05_geometry():
    plan,animations=act05_configuration();rules=json.loads((PROJECT/"data/act05_crt3_rules.json").read_text(encoding="utf8"))
    verify_catalog();catalog=json.loads(CATALOG.read_text(encoding="utf8"));g=catalog["source_geometry"]
    window_specs=rules["hit_windows_source"]+rules.get("independent_windows",[]);helper_ids={int(r["helper_id"])for r in window_specs}|{439,524,6235}
    body_ids={4546,4547,4673,4745,5470}
    clock_ids={int(r["source_id"])for r in window_specs}
    ids=clock_ids|helper_ids|body_ids|{6732,4545,4689,6917,4614,4613}|{v[0]for v in animations.values()}
    symbols=read_source_symbols(ids)
    children=set()
    for ident in helper_ids|body_ids:
        children.update(int(r.get("characterId",-1))for state in source_frames(symbols[ident]).values()for r in state.values()if int(r.get("characterId",-1))>0)
    symbols.update(read_source_symbols(children-set(symbols)))
    def tx(rect,m):
        x,y,w,h=rect;ps=[(m[0]*a+m[2]*b+m[4],m[1]*a+m[3]*b+m[5])for a,b in((x,y),(x+w,y),(x,y+h),(x+w,y+h))];xs,ys=zip(*ps);return[min(xs),min(ys),max(xs)-min(xs),max(ys)-min(ys)]
    def shape_rect(i):
        e=symbols[i];b=e.find("shapeBounds")
        if b is None:return None
        return[int(b.get("Xmin"))/20,int(b.get("Ymin"))/20,(int(b.get("Xmax"))-int(b.get("Xmin")))/20,(int(b.get("Ymax"))-int(b.get("Ymin")))/20]
    def rows(i,f):return[{"source_id":int(r.get("characterId",-1)),"depth":int(depth),"name":r.get("name"),"matrix":source_matrix(r.get("matrix",{})),"alpha_mult":int(r.get("colorTransform",{}).get("alphaMultTerm",256))}for depth,r in source_frames(symbols[i])[f].items()]
    def helper_rect(i):
        boxes=[tx(shape_rect(r["source_id"]),r["matrix"])for r in rows(i,1)if r["source_id"]in symbols and shape_rect(r["source_id"])is not None]
        if not boxes:return None
        x=min(r[0]for r in boxes);y=min(r[1]for r in boxes);return[x,y,max(r[0]+r[2]for r in boxes)-x,max(r[1]+r[3]for r in boxes)-y]
    shapes={str(i):{"rect":helper_rect(i)}for i in helper_ids if helper_rect(i)is not None}
    timelines={}
    for i in {v[0]for v in animations.values()}|clock_ids:
        active={str(f):[{**r,"rect":tx(shapes[str(r["source_id"])]["rect"],r["matrix"])}for r in rows(i,f)if str(r["source_id"])in shapes]for f in source_frames(symbols[i])}
        timelines[str(i)]={"frame_count":len(source_frames(symbols[i])),"active_by_source_frame":{f:rs for f,rs in active.items()if rs},"space":"source action local, actor parent matrix external exactly once"}
    bodies={}
    for i in body_ids:
        stops=[]
        for path in(SOURCES/f"scripts/DefineSprite_{i}").glob("frame_*/DoAction*.as"):
            if re.search(r"(?<!\.)\bstop\s*\(",path.read_text(encoding="utf8")):stops.append(int(path.parent.name.split("_")[1]))
        bodies[str(i)]={"frame_count":len(source_frames(symbols[i])),"rects_by_source_frame":{str(f):[tx(shape_rect(4545),r["matrix"])for r in rows(i,f)if r["source_id"]==4545]for f in source_frames(symbols[i])},"stop_frames":stops}
        if len(stops)==1:bodies[str(i)]["stop_source_frame"]=stops[0]
    g["act05_crt3_body"]={"parents":{str(f):{kind:next((r for r in rows(6732,f)if r["name"]==kind),None)for kind in("몸빵","중력몸빵")}for f in range(101,141)},"clips":bodies,"rect_space":"body inner4545 placement included; parent action placement external once"}
    g["act05_crt3_hit_windows"]={"hit_shapes":shapes,"timelines":timelines,"source":"Original XML display lists; source observers remain explicit rules, not inferred from alpha or PNG overlap"}
    g["player_hit_fx"]["crt_3"]={**g["player_hit_fx"]["crt_2"],"parent_frame":133,"source_filter_equivalence":"Original6732f14/f74/f133 basis,filter,CXFORM compared equal; exactCRT3 offset14.7,35.15"}
    g["act05_crt3_components"]={"screen_feedback":json.loads((PROJECT/"data/act05_crt3_feedback.json").read_text(encoding="utf8")),"e_hit_variants":{str(v["parent_depth"]):v["animation_key"]for v in plan["e_hit_parent_wrappers"]["variants"]},"tracks":plan["independent_placement_tracks"],"cutin":plan["e_cutin"],"reuse_animations":plan["reuse_animations"],"sparse_visual_mapping":plan["sparse_visual_mapping"],"streak":plan["e_streak_wrapper"],"timelines":{str(i):{str(f):rows(i,f)for f in source_frames(symbols[i])}for i in(6276,6199,6299,6278,6259,4614,6308,6156,6067)}}
    provenance=[source_record(SOURCES/"structure/game.xml"),source_record(SOURCES/"symbolClass/symbols.csv")]
    previous={r["path"]:r["sha256"]for r in catalog["outputs"]}
    # Source voices launched by AS2 attachSound, distinct from StartSound tags.
    script_sounds={"crt3_q_random_0":(6138,4,2),"crt3_q_random_1":(6138,4,1),"crt3_f_contact":(6067,2,10),"crt3_slash_contact":(1481,1,4),"crt3_e_random_0":(6259,1,12),"crt3_e_random_1":(6259,1,13),"crt3_e_random_2":(6259,1,9)}
    for alias,(i,f,sid)in script_sounds.items():
        record=act05_sound_asset(sid,previous,provenance);catalog["audio"]["sfx"][alias]=record["path"];catalog["audio_records"][alias]=record;catalog["audio_events"][alias]={"sprite_id":i,"frame":f,"sound_id":sid,"in_point_samples_44100":0,"dispatch":"Original AS2 attachSound; source clock owns choice and once gate"}
    for child in rules["components"]["source_audio"]["nested_candidates"]:
        i=int(child["source_id"])
        if not child.get("events"):continue
        act05_import_sounds(catalog,previous,provenance,i,list(range(1,int(child["actual_frames"])+1)),"crt3_child_"+str(i))
    for i in ids:
        for directory in(SOURCES/"scripts").glob(f"DefineSprite_{i}*"):
            if directory.name==f"DefineSprite_{i}"or directory.name.startswith(f"DefineSprite_{i}_"):provenance.extend(source_record(p)for p in directory.rglob("*.as"))
    act05_publish(catalog,provenance)


def act05_sound_asset(sid,previous,provenance):
    paths=[SOURCES/f"sounds/{sid}.mp3",*(SOURCES/"sounds").glob(f"{sid}_*.mp3")];paths=[p for p in paths if p.exists()]
    if len(paths)!=1:raise ValueError(f"Expected exactly one original sound {sid}: {paths}")
    record=copy_asset(paths[0].relative_to(SOURCES),Path(f"audio/{sid}.mp3"),previous,provenance,sid)
    previous[record["output"]["path"]]=record["output"]["sha256"]
    return record


def act05_publish(catalog,provenance):
    sources={r["path"]:r for r in catalog["sources"]};sources.update({r["path"]:r for r in provenance});catalog["sources"]=list(sources.values())
    outputs={r["path"]:r for r in catalog["outputs"]}
    for row in catalog["animations"].values():
        if "output"in row:outputs[row["output"]["path"]]=row["output"]
    for row in catalog["audio_records"].values():outputs[row["output"]["path"]]=row["output"]
    catalog["outputs"]=list(outputs.values());CATALOG.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+"\n",encoding="utf8");verify_catalog()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inspect-bounds", nargs="*", type=int)
    parser.add_argument("--verify", action="store_true", help="Read-only source/output hash, atlas region and registration checks")
    parser.add_argument("--refresh-animations", nargs="+", help="Regenerate only reviewed existing keys; keep all unrelated assets and metadata")
    parser.add_argument("--training-scene", action="store_true", help="Append the bounded root41 map, ground and source music subset")
    parser.add_argument("--training-hud", action="store_true", help="Append original HUD static art and separate live-field/morph geometry")
    parser.add_argument("--training-title", action="store_true", help="Refresh only root41 title with original instance filters")
    parser.add_argument("--act02-animations", nargs="+", help="Append only reviewed ACT02 default action keys and their source audio events")
    parser.add_argument("--act02-geometry", action="store_true", help="Record bounded default skill collision matrices without regenerating any pixels")
    parser.add_argument("--act03-animations", nargs="+", help="Append explicitly selected CRT1/root9 default components; never regenerate unrelated assets")
    parser.add_argument("--act04-crt2-child-audio", action="store_true", help="Append reviewed CRT2 independent-child source sounds")
    parser.add_argument("--act04-crt1-audio", action="store_true", help="Append only eight reviewed missing CRT1 independent-child sounds")
    parser.add_argument("--act04-geometry", action="store_true", help="Append original CRT2 source bodies, default hit helper placements and independent clocks")
    parser.add_argument("--act05-animations", nargs="+", help="Import only the reviewed CRT3 source plan")
    parser.add_argument("--act05-filtered", action="store_true", help="Derive source-parent glow and color-matrix variants")
    parser.add_argument("--act05-geometry", action="store_true", help="Append CRT3 source geometry and nested/script audio")
    parser.add_argument("--act04-animations", nargs="+", help="Append reviewed CRT2 default/pren variants only; all selects the bounded table")
    parser.add_argument("--act03-geometry", action="store_true", help="Append CRT1 collision/body/independent-clock metadata and7437 shared state placements")
    parser.add_argument("--act03-stage-assets", action="store_true", help="Append root9 map7370 and enemy7430 HP fill, with reviewed sound aliases")
    parser.add_argument("--hud-feedback", action="store_true", help="Append dynamic combo/hover field metadata and original grenade inventory art")
    parser.add_argument("--crt3-hud", action="store_true", help="Append reviewed source4391 page4 only")
    parser.add_argument("--source-warehouse-crt3", action="store_true", help="Append original2728 page5 only")
    parser.add_argument("--crt2-hud", action="store_true", help="Append source4391 page3 and its live slot geometry")
    parser.add_argument("--source-warehouse-crt2", action="store_true", help="Append original2728 page4, preserving default empty item selectors")
    parser.add_argument("--crt1-hud", action="store_true", help="Append original second HUD page and only the already implemented S slot mapping")
    parser.add_argument("--source-ui", action="store_true", help="Append original battle menu, failure and settings art with dynamic controls separated")
    parser.add_argument("--source-dropdown", action="store_true", help="Append source6934 menu navigation and original transition placements")
    parser.add_argument("--source-warehouse", action="store_true", help="Append original default warehouse and existing HP+10 ring path")
    parser.add_argument("--source-warehouse-crt1", action="store_true", help="Append original2728 CRT1 weapon page3 and source2639 ring navigation")
    args = parser.parse_args()
    if args.inspect_bounds:
        print(json.dumps(flash_bounds(args.inspect_bounds), ensure_ascii=False, indent=2))
        return
    if args.verify:
        verify_catalog()
        return
    if args.refresh_animations:
        refresh_animations(args.refresh_animations)
        return
    if args.training_scene:
        build_training_scene()
        return
    if args.training_hud:
        build_training_hud()
        return
    if args.training_title:
        build_training_hud(["training_title"])
        return
    if args.act02_animations:
        append_act02_animations(args.act02_animations)
        return
    if args.act02_geometry:
        append_act02_hit_geometry()
        return
    if args.act03_animations:
        append_act03_animations(args.act03_animations)
        return
    if args.act04_crt2_child_audio:
        append_act04_crt1_audio(2)
        return
    if args.act04_crt1_audio:
        append_act04_crt1_audio()
        return
    if args.act04_geometry:
        append_act04_geometry()
        return
    if args.act05_animations:
        append_act05_animations(args.act05_animations)
        return
    if args.act05_filtered:
        append_act05_filtered()
        return
    if args.act05_geometry:
        append_act05_geometry()
        return
    if args.act04_animations:
        append_act04_animations(args.act04_animations)
        return
    if args.act03_geometry:
        append_act03_geometry()
        return
    if args.act03_stage_assets:
        append_act03_stage_assets()
        return
    if args.hud_feedback:
        build_hud_feedback()
        return
    if args.crt3_hud:
        build_crt3_hud()
        return
    if args.source_warehouse_crt3:
        build_source_warehouse_crt3()
        return
    if args.crt2_hud:
        build_crt2_hud()
        return
    if args.source_warehouse_crt2:
        build_source_warehouse_crt2()
        return
    if args.crt1_hud:
        build_crt1_hud()
        return
    if args.source_ui:
        build_source_ui()
        return
    if args.source_dropdown:
        build_source_dropdown()
        return
    if args.source_warehouse:
        build_source_warehouse()
        return
    if args.source_warehouse_crt1:
        build_source_warehouse_crt1()
        return
    build_catalog()
    build_training_scene()
    build_training_hud()
    append_act02_animations(list(ACT02_ANIMATIONS))
    append_act02_hit_geometry()
    build_hud_feedback()
    build_crt1_hud()
    build_source_ui()
    build_source_dropdown()
    build_source_warehouse()
    build_source_warehouse_crt1()

if __name__ == "__main__":
    main()
