#!/usr/bin/env python3
"""src/ 안의 Lua 스크립트들을 Roblox Studio에서 바로 열 수 있는
XML place 파일(build/CatGame-v{VERSION}.rbxlx)로 묶는다.

사용법:  python3 tools/build_rbxlx.py
바이너리 .rbxl까지 한 번에 만들려면 tools/build.sh 를 쓴다.

파일명에 버전을 붙이는 이유: GitHub raw 링크는 브랜치 파일을 몇 분간 캐싱하기
때문에, 내용을 고쳤으면 VERSION을 올려 새 파일명으로 배포해야 받는 사람이
확실히 최신 파일을 받는다.
"""
import xml.etree.ElementTree as ET
from pathlib import Path

VERSION = 6

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
OUT = ROOT / "build" / ("CatGame-v%d.rbxlx" % VERSION)

_ref_counter = 0


def item(parent, class_name):
    """<Item class=... referent=...><Properties/></Item> 생성"""
    global _ref_counter
    element = ET.SubElement(
        parent, "Item", {"class": class_name, "referent": "RBX%d" % _ref_counter}
    )
    _ref_counter += 1
    props = ET.SubElement(element, "Properties")
    return element, props


def prop(props, tag, name, text=None, children=None):
    element = ET.SubElement(props, tag, {"name": name})
    if text is not None:
        element.text = text
    if children:
        for child_tag, child_text in children:
            sub = ET.SubElement(element, child_tag)
            sub.text = child_text
    return element


def vector3(props, name, x, y, z):
    prop(props, "Vector3", name, children=[("X", str(x)), ("Y", str(y)), ("Z", str(z))])


def cframe(props, name, x, y, z):
    values = [("X", str(x)), ("Y", str(y)), ("Z", str(z)),
              ("R00", "1"), ("R01", "0"), ("R02", "0"),
              ("R10", "0"), ("R11", "1"), ("R12", "0"),
              ("R20", "0"), ("R21", "0"), ("R22", "1")]
    prop(props, "CoordinateFrame", name, children=values)


def color3uint8(r, g, b):
    return str((0xFF << 24) | (r << 16) | (g << 8) | b)


def script_item(parent, class_name, name, source_file):
    element, props = item(parent, class_name)
    prop(props, "string", "Name", name)
    prop(props, "ProtectedString", "Source", source_file.read_text(encoding="utf-8"))
    return element


root = ET.Element("roblox", {"version": "4"})

# ── Workspace: 초록 바닥 + 스폰 지점 ──────────────────────────
workspace, ws_props = item(root, "Workspace")
prop(ws_props, "string", "Name", "Workspace")

_, base_props = item(workspace, "Part")
prop(base_props, "string", "Name", "Baseplate")
prop(base_props, "bool", "Anchored", "true")
prop(base_props, "bool", "Locked", "true")
vector3(base_props, "size", 420, 20, 900)
cframe(base_props, "CFrame", 0, -10, -260)
prop(base_props, "Color3uint8", "Color3uint8", color3uint8(106, 168, 79))
prop(base_props, "token", "TopSurface", "0")
prop(base_props, "token", "BottomSurface", "0")

_, spawn_props = item(workspace, "SpawnLocation")
prop(spawn_props, "string", "Name", "SpawnLocation")
prop(spawn_props, "bool", "Anchored", "true")
vector3(spawn_props, "size", 12, 1, 12)
cframe(spawn_props, "CFrame", 0, 0.5, 0)
prop(spawn_props, "Color3uint8", "Color3uint8", color3uint8(255, 214, 133))
prop(spawn_props, "token", "TopSurface", "0")
prop(spawn_props, "token", "BottomSurface", "0")

# ── 스크립트를 각 서비스에 배치 ─────────────────────────────
replicated, rep_props = item(root, "ReplicatedStorage")
prop(rep_props, "string", "Name", "ReplicatedStorage")
script_item(replicated, "ModuleScript", "CatConfig",
            SRC / "ReplicatedStorage" / "CatConfig.lua")
script_item(replicated, "ModuleScript", "BigNumber",
            SRC / "ReplicatedStorage" / "BigNumber.lua")

server_service, sss_props = item(root, "ServerScriptService")
prop(sss_props, "string", "Name", "ServerScriptService")
script_item(server_service, "Script", "CatGameServer",
            SRC / "ServerScriptService" / "CatGameServer.server.lua")
script_item(server_service, "Script", "CharacterSetup",
            SRC / "ServerScriptService" / "CharacterSetup.server.lua")
script_item(server_service, "Script", "Breakables",
            SRC / "ServerScriptService" / "Breakables.server.lua")
script_item(server_service, "Script", "World",
            SRC / "ServerScriptService" / "World.server.lua")

starter_player, sp_props = item(root, "StarterPlayer")
prop(sp_props, "string", "Name", "StarterPlayer")
prop(sp_props, "bool", "LoadCharacterAppearance", "false")

scripts_folder, sps_props = item(starter_player, "StarterPlayerScripts")
prop(sps_props, "string", "Name", "StarterPlayerScripts")
script_item(scripts_folder, "LocalScript", "CatGameClient",
            SRC / "StarterPlayerScripts" / "CatGameClient.client.lua")
script_item(scripts_folder, "LocalScript", "CatTutorial",
            SRC / "StarterPlayerScripts" / "CatTutorial.client.lua")

# 이름이 Animate인 스크립트를 넣어두면 로블록스 기본 Animate가 들어오지 않는다
char_scripts, scs_props = item(starter_player, "StarterCharacterScripts")
prop(scs_props, "string", "Name", "StarterCharacterScripts")
script_item(char_scripts, "LocalScript", "Animate",
            SRC / "StarterCharacterScripts" / "Animate.client.lua")

ET.indent(root)
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_bytes(ET.tostring(root, encoding="utf-8"))
print("완료: %s (%.1f KB)" % (OUT, OUT.stat().st_size / 1024))
