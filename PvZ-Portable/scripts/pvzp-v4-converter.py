#!/usr/bin/env python3
# Copyright (C) 2026 Zhou Qiankang <wszqkzqk@qq.com>
#
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# This file is part of PvZ-Portable.
#
# PvZ-Portable is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# PvZ-Portable is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with PvZ-Portable. If not, see <https://www.gnu.org/licenses/>.

"""
PvZ-Portable Mid-Level Save File Converter for v4 Format

Converts portable v4 save files (.v4) to human-readable YAML format and back.
This is a LOSSLESS bidirectional converter - you can edit the YAML and convert
it back to a valid v4 save file.

Usage:
    python pvzp-v4-converter.py export <input.v4> <output.yaml>
    python pvzp-v4-converter.py import <input.yaml> <output.v4>
    python pvzp-v4-converter.py info <input.v4>

The YAML format:
- Human-readable fields for game-relevant data (sun, plants, zombies, etc.)
- Base64-encoded binary for complex/internal data (particles, animations, etc.)
- Fully reversible - import produces identical save file

Copyright (C) 2026 wszqkzqk <wszqkzqk@qq.com>

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
"""

import argparse
import base64
import struct
import sys
import zlib
import yaml
from dataclasses import dataclass, field
from enum import IntEnum
from pathlib import Path
from typing import Any, Optional, Type

# ============================================================================
# Constants
# ============================================================================

SAVE_MAGIC = b"PVZP_SAVE4\x00\x00"  # 12 bytes with null padding
SAVE_VERSION = 1
HEADER_SIZE = 24  # magic(12) + version(4) + payloadSize(4) + payloadCrc(4)

# Board constants from Board.h
MAX_ZOMBIE_WAVES = 100
MAX_ZOMBIES_IN_WAVE = 50

# Global option for expanded zombies_in_wave output
# When True, shows each wave's zombie list as human-readable
# When False, keeps as base64 for compactness
EXPAND_ZOMBIES_IN_WAVE = False


class ChunkType(IntEnum):
    """Chunk types in v4 save format."""
    BOARD_BASE = 1
    ZOMBIES = 2
    PLANTS = 3
    PROJECTILES = 4
    COINS = 5
    MOWERS = 6
    GRIDITEMS = 7
    PARTICLE_EMITTERS = 8
    PARTICLE_PARTICLES = 9
    PARTICLE_SYSTEMS = 10
    REANIMATIONS = 11
    TRAILS = 12
    ATTACHMENTS = 13
    CURSOR = 14
    CURSOR_PREVIEW = 15
    ADVICE = 16
    SEEDBANK = 17
    SEEDPACKETS = 18
    CHALLENGE = 19
    MUSIC = 20


# Chunks that we parse into human-readable format
READABLE_CHUNKS = {
    ChunkType.BOARD_BASE,
    ChunkType.ZOMBIES,
    ChunkType.PLANTS,
    ChunkType.MOWERS,
    ChunkType.GRIDITEMS,
    ChunkType.SEEDBANK,
    ChunkType.SEEDPACKETS,
    ChunkType.CHALLENGE,
}

# Chunks kept as binary (too complex or not user-editable)
BINARY_CHUNKS = {
    ChunkType.PROJECTILES,
    ChunkType.COINS,
    ChunkType.PARTICLE_EMITTERS,
    ChunkType.PARTICLE_PARTICLES,
    ChunkType.PARTICLE_SYSTEMS,
    ChunkType.REANIMATIONS,
    ChunkType.TRAILS,
    ChunkType.ATTACHMENTS,
    ChunkType.CURSOR,
    ChunkType.CURSOR_PREVIEW,
    ChunkType.ADVICE,
    ChunkType.MUSIC,
}


# ============================================================================
# Game Enums - mapped from ConstEnums.h
# ============================================================================

class ZombieType(IntEnum):
    ZOMBIE_INVALID = -1
    ZOMBIE_NORMAL = 0
    ZOMBIE_FLAG = 1
    ZOMBIE_TRAFFIC_CONE = 2
    ZOMBIE_POLEVAULTER = 3
    ZOMBIE_PAIL = 4
    ZOMBIE_NEWSPAPER = 5
    ZOMBIE_DOOR = 6
    ZOMBIE_FOOTBALL = 7
    ZOMBIE_DANCER = 8
    ZOMBIE_BACKUP_DANCER = 9
    ZOMBIE_DUCKY_TUBE = 10
    ZOMBIE_SNORKEL = 11
    ZOMBIE_ZAMBONI = 12
    ZOMBIE_BOBSLED = 13
    ZOMBIE_DOLPHIN_RIDER = 14
    ZOMBIE_JACK_IN_THE_BOX = 15
    ZOMBIE_BALLOON = 16
    ZOMBIE_DIGGER = 17
    ZOMBIE_POGO = 18
    ZOMBIE_YETI = 19
    ZOMBIE_BUNGEE = 20
    ZOMBIE_LADDER = 21
    ZOMBIE_CATAPULT = 22
    ZOMBIE_GARGANTUAR = 23
    ZOMBIE_IMP = 24
    ZOMBIE_BOSS = 25
    ZOMBIE_PEA_HEAD = 26
    ZOMBIE_WALLNUT_HEAD = 27
    ZOMBIE_JALAPENO_HEAD = 28
    ZOMBIE_GATLING_HEAD = 29
    ZOMBIE_SQUASH_HEAD = 30
    ZOMBIE_TALLNUT_HEAD = 31
    ZOMBIE_REDEYE_GARGANTUAR = 32


class SeedType(IntEnum):
    SEED_NONE = -1
    SEED_PEASHOOTER = 0
    SEED_SUNFLOWER = 1
    SEED_CHERRYBOMB = 2
    SEED_WALLNUT = 3
    SEED_POTATOMINE = 4
    SEED_SNOWPEA = 5
    SEED_CHOMPER = 6
    SEED_REPEATER = 7
    SEED_PUFFSHROOM = 8
    SEED_SUNSHROOM = 9
    SEED_FUMESHROOM = 10
    SEED_GRAVEBUSTER = 11
    SEED_HYPNOSHROOM = 12
    SEED_SCAREDYSHROOM = 13
    SEED_ICESHROOM = 14
    SEED_DOOMSHROOM = 15
    SEED_LILYPAD = 16
    SEED_SQUASH = 17
    SEED_THREEPEATER = 18
    SEED_TANGLEKELP = 19
    SEED_JALAPENO = 20
    SEED_SPIKEWEED = 21
    SEED_TORCHWOOD = 22
    SEED_TALLNUT = 23
    SEED_SEASHROOM = 24
    SEED_PLANTERN = 25
    SEED_CACTUS = 26
    SEED_BLOVER = 27
    SEED_SPLITPEA = 28
    SEED_STARFRUIT = 29
    SEED_PUMPKINSHELL = 30
    SEED_MAGNETSHROOM = 31
    SEED_CABBAGEPULT = 32
    SEED_FLOWERPOT = 33
    SEED_KERNELPULT = 34
    SEED_INSTANT_COFFEE = 35
    SEED_GARLIC = 36
    SEED_UMBRELLA = 37
    SEED_MARIGOLD = 38
    SEED_MELONPULT = 39
    SEED_GATLINGPEA = 40
    SEED_TWINSUNFLOWER = 41
    SEED_GLOOMSHROOM = 42
    SEED_CATTAIL = 43
    SEED_WINTERMELON = 44
    SEED_GOLD_MAGNET = 45
    SEED_SPIKEROCK = 46
    SEED_COBCANNON = 47
    SEED_IMITATER = 48


class BackgroundType(IntEnum):
    BACKGROUND_1_DAY = 0
    BACKGROUND_2_NIGHT = 1
    BACKGROUND_3_POOL = 2
    BACKGROUND_4_FOG = 3
    BACKGROUND_5_ROOF = 4
    BACKGROUND_6_BOSS = 5
    BACKGROUND_GREENHOUSE = 6
    BACKGROUND_TREEOFWISDOM = 7
    BACKGROUND_ZOMBIQUARIUM = 8


class GridItemType(IntEnum):
    GRIDITEM_NONE = 0
    GRIDITEM_GRAVESTONE = 1
    GRIDITEM_CRATER = 2
    GRIDITEM_LADDER = 3
    GRIDITEM_PORTAL_CIRCLE = 4
    GRIDITEM_PORTAL_SQUARE = 5
    GRIDITEM_BRAIN = 6
    GRIDITEM_SCARY_POT = 7
    GRIDITEM_SQUIRREL = 8
    GRIDITEM_ZEN_TOOL = 9
    GRIDITEM_STINKY = 10
    GRIDITEM_RAKE = 11
    GRIDITEM_IZOMBIE_BRAIN = 12


class MowerType(IntEnum):
    MOWER_LAWN = 0
    MOWER_POOL = 1
    MOWER_ROOF = 2


class MowerState(IntEnum):
    MOWER_ROLLING_IN = 0
    MOWER_READY = 1
    MOWER_TRIGGERED = 2
    MOWER_SQUISHED = 3


class ScaryPotType(IntEnum):
    SCARYPOT_NONE = 0
    SCARYPOT_SEED = 1
    SCARYPOT_ZOMBIE = 2
    SCARYPOT_SUN = 3


# Human-friendly names for display
ZOMBIE_NAMES = {
    ZombieType.ZOMBIE_NORMAL: "Zombie",
    ZombieType.ZOMBIE_FLAG: "Flag Zombie",
    ZombieType.ZOMBIE_TRAFFIC_CONE: "Conehead Zombie",
    ZombieType.ZOMBIE_POLEVAULTER: "Pole Vaulting Zombie",
    ZombieType.ZOMBIE_PAIL: "Buckethead Zombie",
    ZombieType.ZOMBIE_NEWSPAPER: "Newspaper Zombie",
    ZombieType.ZOMBIE_DOOR: "Screen Door Zombie",
    ZombieType.ZOMBIE_FOOTBALL: "Football Zombie",
    ZombieType.ZOMBIE_DANCER: "Dancing Zombie",
    ZombieType.ZOMBIE_BACKUP_DANCER: "Backup Dancer",
    ZombieType.ZOMBIE_DUCKY_TUBE: "Ducky Tube Zombie",
    ZombieType.ZOMBIE_SNORKEL: "Snorkel Zombie",
    ZombieType.ZOMBIE_ZAMBONI: "Zomboni",
    ZombieType.ZOMBIE_BOBSLED: "Zombie Bobsled Team",
    ZombieType.ZOMBIE_DOLPHIN_RIDER: "Dolphin Rider Zombie",
    ZombieType.ZOMBIE_JACK_IN_THE_BOX: "Jack-in-the-Box Zombie",
    ZombieType.ZOMBIE_BALLOON: "Balloon Zombie",
    ZombieType.ZOMBIE_DIGGER: "Digger Zombie",
    ZombieType.ZOMBIE_POGO: "Pogo Zombie",
    ZombieType.ZOMBIE_YETI: "Zombie Yeti",
    ZombieType.ZOMBIE_BUNGEE: "Bungee Zombie",
    ZombieType.ZOMBIE_LADDER: "Ladder Zombie",
    ZombieType.ZOMBIE_CATAPULT: "Catapult Zombie",
    ZombieType.ZOMBIE_GARGANTUAR: "Gargantuar",
    ZombieType.ZOMBIE_IMP: "Imp",
    ZombieType.ZOMBIE_BOSS: "Dr. Zomboss",
    ZombieType.ZOMBIE_REDEYE_GARGANTUAR: "Giga-gargantuar",
}

PLANT_NAMES = {
    SeedType.SEED_PEASHOOTER: "Peashooter",
    SeedType.SEED_SUNFLOWER: "Sunflower",
    SeedType.SEED_CHERRYBOMB: "Cherry Bomb",
    SeedType.SEED_WALLNUT: "Wall-nut",
    SeedType.SEED_POTATOMINE: "Potato Mine",
    SeedType.SEED_SNOWPEA: "Snow Pea",
    SeedType.SEED_CHOMPER: "Chomper",
    SeedType.SEED_REPEATER: "Repeater",
    SeedType.SEED_PUFFSHROOM: "Puff-shroom",
    SeedType.SEED_SUNSHROOM: "Sun-shroom",
    SeedType.SEED_FUMESHROOM: "Fume-shroom",
    SeedType.SEED_GRAVEBUSTER: "Grave Buster",
    SeedType.SEED_HYPNOSHROOM: "Hypno-shroom",
    SeedType.SEED_SCAREDYSHROOM: "Scaredy-shroom",
    SeedType.SEED_ICESHROOM: "Ice-shroom",
    SeedType.SEED_DOOMSHROOM: "Doom-shroom",
    SeedType.SEED_LILYPAD: "Lily Pad",
    SeedType.SEED_SQUASH: "Squash",
    SeedType.SEED_THREEPEATER: "Threepeater",
    SeedType.SEED_TANGLEKELP: "Tangle Kelp",
    SeedType.SEED_JALAPENO: "Jalapeno",
    SeedType.SEED_SPIKEWEED: "Spikeweed",
    SeedType.SEED_TORCHWOOD: "Torchwood",
    SeedType.SEED_TALLNUT: "Tall-nut",
    SeedType.SEED_SEASHROOM: "Sea-shroom",
    SeedType.SEED_PLANTERN: "Plantern",
    SeedType.SEED_CACTUS: "Cactus",
    SeedType.SEED_BLOVER: "Blover",
    SeedType.SEED_SPLITPEA: "Split Pea",
    SeedType.SEED_STARFRUIT: "Starfruit",
    SeedType.SEED_PUMPKINSHELL: "Pumpkin",
    SeedType.SEED_MAGNETSHROOM: "Magnet-shroom",
    SeedType.SEED_CABBAGEPULT: "Cabbage-pult",
    SeedType.SEED_FLOWERPOT: "Flower Pot",
    SeedType.SEED_KERNELPULT: "Kernel-pult",
    SeedType.SEED_INSTANT_COFFEE: "Coffee Bean",
    SeedType.SEED_GARLIC: "Garlic",
    SeedType.SEED_UMBRELLA: "Umbrella Leaf",
    SeedType.SEED_MARIGOLD: "Marigold",
    SeedType.SEED_MELONPULT: "Melon-pult",
    SeedType.SEED_GATLINGPEA: "Gatling Pea",
    SeedType.SEED_TWINSUNFLOWER: "Twin Sunflower",
    SeedType.SEED_GLOOMSHROOM: "Gloom-shroom",
    SeedType.SEED_CATTAIL: "Cattail",
    SeedType.SEED_WINTERMELON: "Winter Melon",
    SeedType.SEED_GOLD_MAGNET: "Gold Magnet",
    SeedType.SEED_SPIKEROCK: "Spikerock",
    SeedType.SEED_COBCANNON: "Cob Cannon",
    SeedType.SEED_IMITATER: "Imitater",
}


def enum_name(enum_class: Type[IntEnum], value: int, default: str = "UNKNOWN") -> str:
    """Get enum name from value, returning default if not found."""
    try:
        return enum_class(value).name
    except ValueError:
        return f"{default}_{value}"


def enum_value(enum_class: Type[IntEnum], name: str, default: int = 0) -> int:
    """Get enum value from name, returning default if not found."""
    if isinstance(name, int):
        return name
    try:
        return enum_class[name].value
    except KeyError:
        # Try parsing as "UNKNOWN_N" format
        if "_" in name:
            try:
                return int(name.rsplit("_", 1)[1])
            except ValueError:
                pass
        return default


# ============================================================================
# Binary Reader/Writer Helpers
# ============================================================================

class BinaryReader:
    """Helper class for reading binary data in little-endian format."""
    
    def __init__(self, data: bytes):
        self.data = data
        self.pos = 0
    
    @property
    def remaining(self) -> int:
        return len(self.data) - self.pos
    
    def read_bytes(self, n: int) -> bytes:
        if self.pos + n > len(self.data):
            raise ValueError(f"Not enough data: need {n}, have {self.remaining}")
        result = self.data[self.pos:self.pos + n]
        self.pos += n
        return result
    
    def read_u8(self) -> int:
        return struct.unpack("<B", self.read_bytes(1))[0]
    
    def read_u32(self) -> int:
        return struct.unpack("<I", self.read_bytes(4))[0]
    
    def read_i32(self) -> int:
        return struct.unpack("<i", self.read_bytes(4))[0]
    
    def read_u64(self) -> int:
        return struct.unpack("<Q", self.read_bytes(8))[0]
    
    def read_i64(self) -> int:
        return struct.unpack("<q", self.read_bytes(8))[0]
    
    def read_f32(self) -> float:
        return struct.unpack("<f", self.read_bytes(4))[0]
    
    def read_bool(self) -> bool:
        return self.read_u8() != 0


class BinaryWriter:
    """Helper class for writing binary data in little-endian format."""
    
    def __init__(self):
        self.data = bytearray()
    
    def write_bytes(self, data: bytes):
        self.data.extend(data)
    
    def write_u8(self, value: int):
        self.data.extend(struct.pack("<B", value & 0xFF))
    
    def write_u32(self, value: int):
        self.data.extend(struct.pack("<I", value & 0xFFFFFFFF))
    
    def write_i32(self, value: int):
        self.data.extend(struct.pack("<i", value))
    
    def write_u64(self, value: int):
        self.data.extend(struct.pack("<Q", value & 0xFFFFFFFFFFFFFFFF))
    
    def write_i64(self, value: int):
        self.data.extend(struct.pack("<q", value))
    
    def write_f32(self, value: float):
        self.data.extend(struct.pack("<f", value))
    
    def write_bool(self, value: bool):
        self.write_u8(1 if value else 0)
    
    def get_bytes(self) -> bytes:
        return bytes(self.data)


# ============================================================================
# TLV Parsing
# ============================================================================

def parse_tlv_fields(data: bytes) -> dict[int, bytes]:
    """Parse TLV (Type-Length-Value) encoded fields."""
    reader = BinaryReader(data)
    fields = {}
    while reader.remaining >= 8:
        field_id = reader.read_u32()
        field_size = reader.read_u32()
        if reader.remaining < field_size:
            break
        field_data = reader.read_bytes(field_size)
        fields[field_id] = field_data
    return fields


def write_tlv_field(writer: BinaryWriter, field_id: int, field_data: bytes):
    """Write a TLV field."""
    writer.write_u32(field_id)
    writer.write_u32(len(field_data))
    writer.write_bytes(field_data)


def write_tlv_fields(fields: dict[int, bytes]) -> bytes:
    """Write multiple TLV fields."""
    writer = BinaryWriter()
    for field_id in sorted(fields.keys()):
        write_tlv_field(writer, field_id, fields[field_id])
    return writer.get_bytes()


# ============================================================================
# Data Array Parsing (for game object collections)
# ============================================================================

@dataclass
class DataArrayHeader:
    free_list_head: int = 0
    max_used_count: int = 0
    size: int = 0
    next_key: int = 0
    max_size: int = 0


@dataclass 
class DataArrayItem:
    item_id: int = 0
    data: bytes = field(default_factory=bytes)
    fields: dict = field(default_factory=dict)


def parse_data_array_tlv(data: bytes) -> tuple[DataArrayHeader, list[DataArrayItem]]:
    """Parse a DataArray with TLV-encoded items."""
    reader = BinaryReader(data)
    header = DataArrayHeader(
        free_list_head=reader.read_u32(),
        max_used_count=reader.read_u32(),
        size=reader.read_u32(),
        next_key=reader.read_u32(),
        max_size=reader.read_u32()
    )
    items = []
    for _ in range(header.max_used_count):
        item_id = reader.read_u32()
        item_size = reader.read_u32()
        item_data = reader.read_bytes(item_size) if item_size > 0 else b""
        item = DataArrayItem(item_id=item_id, data=item_data)
        if item_data:
            item.fields = parse_tlv_fields(item_data)
        items.append(item)
    return header, items


def write_data_array_tlv(header: DataArrayHeader, items: list[DataArrayItem]) -> bytes:
    """Write a DataArray with TLV-encoded items."""
    writer = BinaryWriter()
    writer.write_u32(header.free_list_head)
    writer.write_u32(header.max_used_count)
    writer.write_u32(header.size)
    writer.write_u32(header.next_key)
    writer.write_u32(header.max_size)
    for item in items:
        writer.write_u32(item.item_id)
        writer.write_u32(len(item.data))
        if item.data:
            writer.write_bytes(item.data)
    return writer.get_bytes()


# ============================================================================
# Rect Helper
# ============================================================================

def parse_rect(reader: BinaryReader) -> dict:
    """Parse a Rect structure."""
    return {
        "x": reader.read_i32(),
        "y": reader.read_i32(),
        "width": reader.read_i32(),
        "height": reader.read_i32()
    }


def write_rect(writer: BinaryWriter, rect: dict):
    """Write a Rect structure."""
    writer.write_i32(rect.get("x", 0))
    writer.write_i32(rect.get("y", 0))
    writer.write_i32(rect.get("width", 0))
    writer.write_i32(rect.get("height", 0))


# ============================================================================
# GameObject Base
# ============================================================================

def parse_game_object(data: bytes) -> dict:
    """Parse base GameObject fields."""
    reader = BinaryReader(data)
    return {
        "x": reader.read_i32(),
        "y": reader.read_i32(),
        "width": reader.read_i32(),
        "height": reader.read_i32(),
        "visible": reader.read_bool(),
        "row": reader.read_i32(),
        "render_order": reader.read_i32()
    }


def write_game_object(obj: dict) -> bytes:
    """Write base GameObject fields."""
    writer = BinaryWriter()
    writer.write_i32(obj.get("x", 0))
    writer.write_i32(obj.get("y", 0))
    writer.write_i32(obj.get("width", 0))
    writer.write_i32(obj.get("height", 0))
    writer.write_bool(obj.get("visible", True))
    writer.write_i32(obj.get("row", 0))
    writer.write_i32(obj.get("render_order", 0))
    return writer.get_bytes()


# ============================================================================
# Board Base Field Definitions
# ============================================================================

# Field ID -> (name, type, is_array, array_size)
# Types: bool, i32, i64, f32, enum:EnumName, raw
BOARD_FIELDS = {
    1: ("paused", "bool", False, 0),
    2: ("grid_square_type", "raw", True, 0),  # Complex array
    3: ("grid_cel_look", "raw", True, 0),
    4: ("grid_cel_offset", "raw", True, 0),
    5: ("grid_cel_fog", "raw", True, 0),
    6: ("enable_gravestones", "bool", False, 0),
    7: ("special_gravestone_x", "i32", False, 0),
    8: ("special_gravestone_y", "i32", False, 0),
    9: ("fog_offset", "f32", False, 0),
    10: ("fog_blown_countdown", "i32", False, 0),
    11: ("plant_row", "raw", True, 0),
    12: ("wave_row_got_lawnmowered", "raw", True, 0),
    13: ("bonus_lawnmowers_remaining", "i32", False, 0),
    14: ("ice_min_x", "raw", True, 0),
    15: ("ice_timer", "raw", True, 0),
    16: ("ice_particle_id", "raw", True, 0),
    17: ("row_picking_array", "raw", True, 0),
    18: ("zombies_in_wave", "raw", True, 0),
    19: ("zombie_allowed", "raw", True, 0),
    20: ("sun_countdown", "i32", False, 0),
    21: ("num_suns_fallen", "i32", False, 0),
    22: ("shake_counter", "i32", False, 0),
    23: ("shake_amount_x", "i32", False, 0),
    24: ("shake_amount_y", "i32", False, 0),
    25: ("background", "enum:BackgroundType", False, 0),
    26: ("level", "i32", False, 0),
    27: ("sod_position", "i32", False, 0),
    28: ("prev_mouse_x", "i32", False, 0),
    29: ("prev_mouse_y", "i32", False, 0),
    30: ("sun_money", "i32", False, 0),
    31: ("num_waves", "i32", False, 0),
    32: ("main_counter", "i32", False, 0),
    33: ("effect_counter", "i32", False, 0),
    34: ("draw_count", "i32", False, 0),
    35: ("rise_from_grave_counter", "i32", False, 0),
    36: ("out_of_money_counter", "i32", False, 0),
    37: ("current_wave", "i32", False, 0),
    38: ("total_spawned_waves", "i32", False, 0),
    39: ("tutorial_state", "i32", False, 0),
    40: ("tutorial_particle_id", "raw", False, 0),
    41: ("tutorial_timer", "i32", False, 0),
    42: ("last_bungee_wave", "i32", False, 0),
    43: ("zombie_health_to_next_wave", "i32", False, 0),
    44: ("zombie_health_wave_start", "i32", False, 0),
    45: ("zombie_countdown", "i32", False, 0),
    46: ("zombie_countdown_start", "i32", False, 0),
    47: ("huge_wave_countdown", "i32", False, 0),
    48: ("help_displayed", "raw", True, 0),
    49: ("help_index", "i32", False, 0),
    50: ("final_boss_killed", "bool", False, 0),
    51: ("show_shovel", "bool", False, 0),
    52: ("coin_bank_fade_count", "i32", False, 0),
    53: ("debug_text_mode", "i32", False, 0),
    54: ("level_complete", "bool", False, 0),
    55: ("board_fade_out_counter", "i32", False, 0),
    56: ("next_survival_stage_counter", "i32", False, 0),
    57: ("score_next_mower_counter", "i32", False, 0),
    58: ("level_award_spawned", "bool", False, 0),
    59: ("progress_meter_width", "i32", False, 0),
    60: ("flag_raise_counter", "i32", False, 0),
    61: ("ice_trap_counter", "i32", False, 0),
    62: ("board_rand_seed", "i32", False, 0),
    63: ("pool_sparkly_particle_id", "raw", False, 0),
    64: ("fwoosh_id", "raw", True, 0),
    65: ("fwoosh_countdown", "i32", False, 0),
    66: ("time_stop_counter", "i32", False, 0),
    67: ("dropped_first_coin", "bool", False, 0),
    68: ("final_wave_sound_counter", "i32", False, 0),
    69: ("cob_cannon_cursor_delay_counter", "i32", False, 0),
    70: ("cob_cannon_mouse_x", "i32", False, 0),
    71: ("cob_cannon_mouse_y", "i32", False, 0),
    72: ("killed_yeti", "bool", False, 0),
    73: ("mustache_mode", "bool", False, 0),
    74: ("super_mower_mode", "bool", False, 0),
    75: ("future_mode", "bool", False, 0),
    76: ("pinata_mode", "bool", False, 0),
    77: ("dance_mode", "bool", False, 0),
    78: ("daisy_mode", "bool", False, 0),
    79: ("sukhbir_mode", "bool", False, 0),
    80: ("prev_board_result", "i32", False, 0),
    81: ("triggered_lawnmowers", "i32", False, 0),
    82: ("play_time_active_level", "i32", False, 0),
    83: ("play_time_inactive_level", "i32", False, 0),
    84: ("max_sun_plants", "i32", False, 0),
    85: ("start_draw_time", "i64", False, 0),
    86: ("interval_draw_time", "i64", False, 0),
    87: ("interval_draw_count_start", "i32", False, 0),
    88: ("min_fps", "f32", False, 0),
    89: ("preload_time", "i32", False, 0),
    90: ("game_id", "i64", False, 0),
    91: ("graves_cleared", "i32", False, 0),
    92: ("plants_eaten", "i32", False, 0),
    93: ("plants_shoveled", "i32", False, 0),
    94: ("pea_shooter_used", "bool", False, 0),
    95: ("catapult_plants_used", "bool", False, 0),
    96: ("mushroom_and_coffee_beans_only", "bool", False, 0),
    97: ("mushrooms_used", "bool", False, 0),
    98: ("level_coins_collected", "i32", False, 0),
    99: ("gargantuars_kills_by_corn_cob", "i32", False, 0),
    100: ("coins_collected", "i32", False, 0),
    101: ("diamonds_collected", "i32", False, 0),
    102: ("potted_plants_collected", "i32", False, 0),
    103: ("chocolate_collected", "i32", False, 0),
}


def parse_zombies_in_wave(data: bytes) -> list[list[str]]:
    """Parse zombies_in_wave as 2D array of zombie types.
    
    Format: [MAX_ZOMBIE_WAVES][MAX_ZOMBIES_IN_WAVE] = 100 x 50 int32 values
    Each wave ends with ZOMBIE_INVALID (-1) marker.
    Returns list of waves, each wave is a list of zombie type names.
    """
    reader = BinaryReader(data)
    waves: list[list[str]] = []
    
    for _ in range(MAX_ZOMBIE_WAVES):
        wave: list[str] = []
        for _ in range(MAX_ZOMBIES_IN_WAVE):
            zombie_type = reader.read_i32()
            if zombie_type == ZombieType.ZOMBIE_INVALID:
                # Rest of this wave is padding, skip to next wave
                remaining_in_wave = MAX_ZOMBIES_IN_WAVE - len(wave) - 1
                reader.pos += remaining_in_wave * 4
                break
            wave.append(enum_name(ZombieType, zombie_type))
        waves.append(wave)
    
    return waves


def write_zombies_in_wave(waves: list[list[str]]) -> bytes:
    """Write zombies_in_wave back to binary format.
    
    Takes a list of waves, each containing zombie type names.
    Pads with ZOMBIE_INVALID to fill the array.
    """
    writer = BinaryWriter()
    
    for wave_idx in range(MAX_ZOMBIE_WAVES):
        if wave_idx < len(waves):
            wave = waves[wave_idx]
            for z_idx in range(MAX_ZOMBIES_IN_WAVE):
                if z_idx < len(wave):
                    writer.write_i32(enum_value(ZombieType, wave[z_idx], -1))
                else:
                    writer.write_i32(ZombieType.ZOMBIE_INVALID)
        else:
            # Empty wave
            for _ in range(MAX_ZOMBIES_IN_WAVE):
                writer.write_i32(ZombieType.ZOMBIE_INVALID)
    
    return writer.get_bytes()


def parse_board_field(field_id: int, data: bytes) -> tuple[str, Any]:
    """Parse a single board base field."""
    if field_id not in BOARD_FIELDS:
        return f"_unknown_{field_id}", base64.b64encode(data).decode('ascii')
    
    name, field_type, is_array, _ = BOARD_FIELDS[field_id]
    
    # Special handling for zombies_in_wave
    if field_id == 18 and EXPAND_ZOMBIES_IN_WAVE:
        return name, parse_zombies_in_wave(data)
    
    if field_type == "raw" or is_array:
        # Keep as base64 for complex/array fields
        return name, base64.b64encode(data).decode('ascii')
    
    reader = BinaryReader(data)
    
    if field_type == "bool":
        return name, reader.read_bool()
    elif field_type == "i32":
        return name, reader.read_i32()
    elif field_type == "i64":
        return name, reader.read_i64()
    elif field_type == "f32":
        return name, reader.read_f32()
    elif field_type.startswith("enum:"):
        enum_name_str = field_type.split(":")[1]
        value = reader.read_i32()
        if enum_name_str == "BackgroundType":
            return name, enum_name(BackgroundType, value)
        return name, value
    else:
        return name, base64.b64encode(data).decode('ascii')


def write_board_field(name: str, value: Any) -> tuple[int, bytes] | tuple[None, None]:
    """Write a single board base field. Returns (field_id, data) or (None, None)."""
    # Find field ID by name
    field_id: int | None = None
    field_def: tuple[str, str, bool, int] | None = None
    for fid, (fname, ftype, is_array, arr_size) in BOARD_FIELDS.items():
        if fname == name:
            field_id = fid
            field_def = (fname, ftype, is_array, arr_size)
            break
    
    # Handle unknown fields
    if field_id is None or field_def is None:
        if name.startswith("_unknown_"):
            try:
                parsed_id = int(name.split("_")[-1])
                return parsed_id, base64.b64decode(value)
            except (ValueError, TypeError):
                return None, None
        return None, None
    
    fname, field_type, is_array, _ = field_def
    
    # Special handling for zombies_in_wave
    if field_id == 18:
        if isinstance(value, list):
            # Expanded format - list of waves
            return field_id, write_zombies_in_wave(value)
        elif isinstance(value, str):
            # Base64 format
            return field_id, base64.b64decode(value)
        return field_id, value
    
    # Handle raw/array fields
    if field_type == "raw" or is_array:
        if isinstance(value, str):
            return field_id, base64.b64decode(value)
        return field_id, value
    
    writer = BinaryWriter()
    
    if field_type == "bool":
        writer.write_bool(value)
    elif field_type == "i32":
        writer.write_i32(int(value))
    elif field_type == "i64":
        writer.write_i64(int(value))
    elif field_type == "f32":
        writer.write_f32(float(value))
    elif field_type.startswith("enum:"):
        enum_name_str = field_type.split(":")[1]
        if enum_name_str == "BackgroundType":
            writer.write_i32(enum_value(BackgroundType, value))
        else:
            writer.write_i32(int(value) if isinstance(value, int) else 0)
    else:
        return field_id, base64.b64decode(value) if isinstance(value, str) else value
    
    return field_id, writer.get_bytes()


def parse_board_base(data: bytes) -> dict:
    """Parse BOARD_BASE chunk inner data."""
    reader = BinaryReader(data)
    blob_size = reader.read_u32()
    blob_data = reader.read_bytes(blob_size)
    
    fields = parse_tlv_fields(blob_data)
    result = {}
    for field_id, field_data in fields.items():
        name, value = parse_board_field(field_id, field_data)
        result[name] = value
    return result


def write_board_base(board: dict) -> bytes:
    """Write BOARD_BASE chunk inner data."""
    fields = {}
    for name, value in board.items():
        field_id, field_data = write_board_field(name, value)
        if field_id is not None and field_data is not None:
            fields[field_id] = field_data
    
    blob_data = write_tlv_fields(fields)
    writer = BinaryWriter()
    writer.write_u32(len(blob_data))
    writer.write_bytes(blob_data)
    return writer.get_bytes()


# ============================================================================
# Zombie Parsing
# ============================================================================

def parse_zombie_tail(data: bytes) -> dict:
    """Parse Zombie tail fields (field 100)."""
    reader = BinaryReader(data)
    zombie = {
        "zombie_type": enum_name(ZombieType, reader.read_i32()),
        "zombie_phase": reader.read_i32(),
        "pos_x": reader.read_f32(),
        "pos_y": reader.read_f32(),
        "vel_x": reader.read_f32(),
        "anim_counter": reader.read_i32(),
        "groan_counter": reader.read_i32(),
        "anim_ticks_per_frame": reader.read_i32(),
        "anim_frames": reader.read_i32(),
        "frame": reader.read_i32(),
        "prev_frame": reader.read_i32(),
        "variant": reader.read_bool(),
        "is_eating": reader.read_bool(),
        "just_got_shot_counter": reader.read_i32(),
        "shield_just_got_shot_counter": reader.read_i32(),
        "shield_recoil_counter": reader.read_i32(),
        "zombie_age": reader.read_i32(),
        "zombie_height": reader.read_i32(),
        "phase_counter": reader.read_i32(),
        "from_wave": reader.read_i32(),
        "dropped_loot": reader.read_bool(),
        "zombie_fade": reader.read_i32(),
        "flat_tires": reader.read_bool(),
        "use_ladder_col": reader.read_i32(),
        "target_col": reader.read_i32(),
        "altitude": reader.read_f32(),
        "hit_umbrella": reader.read_bool(),
        "zombie_rect": parse_rect(reader),
        "zombie_attack_rect": parse_rect(reader),
        "chilled_counter": reader.read_i32(),
        "buttered_counter": reader.read_i32(),
        "ice_trap_counter": reader.read_i32(),
        "mind_controlled": reader.read_bool(),
        "blowing_away": reader.read_bool(),
        "has_head": reader.read_bool(),
        "has_arm": reader.read_bool(),
        "has_object": reader.read_bool(),
        "in_pool": reader.read_bool(),
        "on_high_ground": reader.read_bool(),
        "yucky_face": reader.read_bool(),
        "yucky_face_counter": reader.read_i32(),
        "helm_type": reader.read_i32(),
        "body_health": reader.read_i32(),
        "body_max_health": reader.read_i32(),
        "helm_health": reader.read_i32(),
        "helm_max_health": reader.read_i32(),
        "shield_type": reader.read_i32(),
        "shield_health": reader.read_i32(),
        "shield_max_health": reader.read_i32(),
        "flying_health": reader.read_i32(),
        "flying_max_health": reader.read_i32(),
        "dead": reader.read_bool(),
    }
    # Remaining bytes as base64
    if reader.remaining > 0:
        zombie["_extra"] = base64.b64encode(reader.read_bytes(reader.remaining)).decode('ascii')
    return zombie


def write_zombie_tail(zombie: dict) -> bytes:
    """Write Zombie tail fields."""
    writer = BinaryWriter()
    writer.write_i32(enum_value(ZombieType, zombie.get("zombie_type", "ZOMBIE_NORMAL")))
    writer.write_i32(zombie.get("zombie_phase", 0))
    writer.write_f32(zombie.get("pos_x", 0.0))
    writer.write_f32(zombie.get("pos_y", 0.0))
    writer.write_f32(zombie.get("vel_x", 0.0))
    writer.write_i32(zombie.get("anim_counter", 0))
    writer.write_i32(zombie.get("groan_counter", 0))
    writer.write_i32(zombie.get("anim_ticks_per_frame", 0))
    writer.write_i32(zombie.get("anim_frames", 0))
    writer.write_i32(zombie.get("frame", 0))
    writer.write_i32(zombie.get("prev_frame", 0))
    writer.write_bool(zombie.get("variant", False))
    writer.write_bool(zombie.get("is_eating", False))
    writer.write_i32(zombie.get("just_got_shot_counter", 0))
    writer.write_i32(zombie.get("shield_just_got_shot_counter", 0))
    writer.write_i32(zombie.get("shield_recoil_counter", 0))
    writer.write_i32(zombie.get("zombie_age", 0))
    writer.write_i32(zombie.get("zombie_height", 0))
    writer.write_i32(zombie.get("phase_counter", 0))
    writer.write_i32(zombie.get("from_wave", 0))
    writer.write_bool(zombie.get("dropped_loot", False))
    writer.write_i32(zombie.get("zombie_fade", 0))
    writer.write_bool(zombie.get("flat_tires", False))
    writer.write_i32(zombie.get("use_ladder_col", 0))
    writer.write_i32(zombie.get("target_col", 0))
    writer.write_f32(zombie.get("altitude", 0.0))
    writer.write_bool(zombie.get("hit_umbrella", False))
    write_rect(writer, zombie.get("zombie_rect") or {})
    write_rect(writer, zombie.get("zombie_attack_rect") or {})
    writer.write_i32(zombie.get("chilled_counter", 0))
    writer.write_i32(zombie.get("buttered_counter", 0))
    writer.write_i32(zombie.get("ice_trap_counter", 0))
    writer.write_bool(zombie.get("mind_controlled", False))
    writer.write_bool(zombie.get("blowing_away", False))
    writer.write_bool(zombie.get("has_head", True))
    writer.write_bool(zombie.get("has_arm", True))
    writer.write_bool(zombie.get("has_object", True))
    writer.write_bool(zombie.get("in_pool", False))
    writer.write_bool(zombie.get("on_high_ground", False))
    writer.write_bool(zombie.get("yucky_face", False))
    writer.write_i32(zombie.get("yucky_face_counter", 0))
    writer.write_i32(zombie.get("helm_type", 0))
    writer.write_i32(zombie.get("body_health", 0))
    writer.write_i32(zombie.get("body_max_health", 0))
    writer.write_i32(zombie.get("helm_health", 0))
    writer.write_i32(zombie.get("helm_max_health", 0))
    writer.write_i32(zombie.get("shield_type", 0))
    writer.write_i32(zombie.get("shield_health", 0))
    writer.write_i32(zombie.get("shield_max_health", 0))
    writer.write_i32(zombie.get("flying_health", 0))
    writer.write_i32(zombie.get("flying_max_health", 0))
    writer.write_bool(zombie.get("dead", False))
    # Write extra bytes
    if "_extra" in zombie:
        writer.write_bytes(base64.b64decode(zombie["_extra"]))
    return writer.get_bytes()


# ============================================================================
# Plant Parsing
# ============================================================================

MAX_MAGNET_ITEMS = 5

def parse_magnet_item(reader: BinaryReader) -> dict:
    """Parse a single MagnetItem."""
    return {
        "pos_x": reader.read_f32(),
        "pos_y": reader.read_f32(),
        "dest_offset_x": reader.read_f32(),
        "dest_offset_y": reader.read_f32(),
        "item_type": reader.read_i32(),
    }

def write_magnet_item(writer: BinaryWriter, item: dict):
    """Write a single MagnetItem."""
    writer.write_f32(item.get("pos_x", 0.0))
    writer.write_f32(item.get("pos_y", 0.0))
    writer.write_f32(item.get("dest_offset_x", 0.0))
    writer.write_f32(item.get("dest_offset_y", 0.0))
    writer.write_i32(item.get("item_type", 0))

def parse_plant_tail(data: bytes) -> dict:
    """Parse Plant tail fields (field 100)."""
    reader = BinaryReader(data)
    plant = {
        "seed_type": enum_name(SeedType, reader.read_i32()),
        "plant_col": reader.read_i32(),
        "anim_counter": reader.read_i32(),
        "frame": reader.read_i32(),
        "frame_length": reader.read_i32(),
        "num_frames": reader.read_i32(),
        "state": reader.read_i32(),
        "plant_health": reader.read_i32(),
        "plant_max_health": reader.read_i32(),
        "subclass": reader.read_i32(),
        "disappear_countdown": reader.read_i32(),
        "do_special_countdown": reader.read_i32(),
        "state_countdown": reader.read_i32(),
        "launch_counter": reader.read_i32(),
        "launch_rate": reader.read_i32(),
        "plant_rect": parse_rect(reader),
        "plant_attack_rect": parse_rect(reader),
        "target_x": reader.read_i32(),
        "target_y": reader.read_i32(),
        "start_row": reader.read_i32(),
        "particle_id": reader.read_u32(),
        "shooting_counter": reader.read_i32(),
        "body_reanim_id": reader.read_u32(),
        "head_reanim_id": reader.read_u32(),
        "head_reanim_id2": reader.read_u32(),
        "head_reanim_id3": reader.read_u32(),
        "blink_reanim_id": reader.read_u32(),
        "light_reanim_id": reader.read_u32(),
        "sleeping_reanim_id": reader.read_u32(),
        "blink_countdown": reader.read_i32(),
        "recently_eaten_countdown": reader.read_i32(),
        "eaten_flash_countdown": reader.read_i32(),
        "beghouled_flash_countdown": reader.read_i32(),
        "shake_offset_x": reader.read_f32(),
        "shake_offset_y": reader.read_f32(),
        "magnet_items": [parse_magnet_item(reader) for _ in range(MAX_MAGNET_ITEMS)],
        "target_zombie_id": reader.read_u32(),
        "wake_up_counter": reader.read_i32(),
        "on_bungee_state": reader.read_i32(),
        "imitater_type": enum_name(SeedType, reader.read_i32()),
        "potted_plant_index": reader.read_i32(),
        "anim_ping": reader.read_bool(),
        "dead": reader.read_bool(),
        "squished": reader.read_bool(),
        "is_asleep": reader.read_bool(),
        "is_on_board": reader.read_bool(),
        "highlighted": reader.read_bool(),
    }
    # Remaining bytes as base64 (should be none for current format)
    if reader.remaining > 0:
        plant["_extra"] = base64.b64encode(reader.read_bytes(reader.remaining)).decode('ascii')
    return plant


def write_plant_tail(plant: dict) -> bytes:
    """Write Plant tail fields."""
    writer = BinaryWriter()
    writer.write_i32(enum_value(SeedType, plant.get("seed_type", "SEED_PEASHOOTER")))
    writer.write_i32(plant.get("plant_col", 0))
    writer.write_i32(plant.get("anim_counter", 0))
    writer.write_i32(plant.get("frame", 0))
    writer.write_i32(plant.get("frame_length", 0))
    writer.write_i32(plant.get("num_frames", 0))
    writer.write_i32(plant.get("state", 0))
    writer.write_i32(plant.get("plant_health", 300))
    writer.write_i32(plant.get("plant_max_health", 300))
    writer.write_i32(plant.get("subclass", 0))
    writer.write_i32(plant.get("disappear_countdown", 0))
    writer.write_i32(plant.get("do_special_countdown", 0))
    writer.write_i32(plant.get("state_countdown", 0))
    writer.write_i32(plant.get("launch_counter", 0))
    writer.write_i32(plant.get("launch_rate", 0))
    write_rect(writer, plant.get("plant_rect") or {})
    write_rect(writer, plant.get("plant_attack_rect") or {})
    writer.write_i32(plant.get("target_x", 0))
    writer.write_i32(plant.get("target_y", 0))
    writer.write_i32(plant.get("start_row", 0))
    writer.write_u32(plant.get("particle_id", 0))
    writer.write_i32(plant.get("shooting_counter", 0))
    writer.write_u32(plant.get("body_reanim_id", 0))
    writer.write_u32(plant.get("head_reanim_id", 0))
    writer.write_u32(plant.get("head_reanim_id2", 0))
    writer.write_u32(plant.get("head_reanim_id3", 0))
    writer.write_u32(plant.get("blink_reanim_id", 0))
    writer.write_u32(plant.get("light_reanim_id", 0))
    writer.write_u32(plant.get("sleeping_reanim_id", 0))
    writer.write_i32(plant.get("blink_countdown", 0))
    writer.write_i32(plant.get("recently_eaten_countdown", 0))
    writer.write_i32(plant.get("eaten_flash_countdown", 0))
    writer.write_i32(plant.get("beghouled_flash_countdown", 0))
    writer.write_f32(plant.get("shake_offset_x", 0.0))
    writer.write_f32(plant.get("shake_offset_y", 0.0))
    # Write magnet items
    magnet_items = plant.get("magnet_items") or [{} for _ in range(MAX_MAGNET_ITEMS)]
    for i in range(MAX_MAGNET_ITEMS):
        item = magnet_items[i] if i < len(magnet_items) else {}
        write_magnet_item(writer, item)
    writer.write_u32(plant.get("target_zombie_id", 0))
    writer.write_i32(plant.get("wake_up_counter", 0))
    writer.write_i32(plant.get("on_bungee_state", 0))
    writer.write_i32(enum_value(SeedType, plant.get("imitater_type", "SEED_NONE")))
    writer.write_i32(plant.get("potted_plant_index", -1))
    writer.write_bool(plant.get("anim_ping", False))
    writer.write_bool(plant.get("dead", False))
    writer.write_bool(plant.get("squished", False))
    writer.write_bool(plant.get("is_asleep", False))
    writer.write_bool(plant.get("is_on_board", True))
    writer.write_bool(plant.get("highlighted", False))
    # Write extra bytes if any
    if "_extra" in plant:
        writer.write_bytes(base64.b64decode(plant["_extra"]))
    return writer.get_bytes()



# ============================================================================
# Mower Parsing
# ============================================================================

def parse_mower_tail(data: bytes) -> dict:
    """Parse LawnMower tail fields (field 100)."""
    reader = BinaryReader(data)
    mower = {
        "pos_x": reader.read_f32(),
        "pos_y": reader.read_f32(),
        "render_order": reader.read_i32(),
        "row": reader.read_i32(),
        "anim_ticks_per_frame": reader.read_i32(),
        "reanim_id": reader.read_u32(),
        "chomp_counter": reader.read_i32(),
        "rolling_in_counter": reader.read_i32(),
        "squished_counter": reader.read_i32(),
        "mower_state": enum_name(MowerState, reader.read_i32()),
        "dead": reader.read_bool(),
        "visible": reader.read_bool(),
        "mower_type": enum_name(MowerType, reader.read_i32()),
        "altitude": reader.read_f32(),
        "mower_height": reader.read_i32(),
        "last_portal_x": reader.read_i32(),
    }
    return mower


def write_mower_tail(mower: dict) -> bytes:
    """Write LawnMower tail fields."""
    writer = BinaryWriter()
    writer.write_f32(mower.get("pos_x", 0.0))
    writer.write_f32(mower.get("pos_y", 0.0))
    writer.write_i32(mower.get("render_order", 0))
    writer.write_i32(mower.get("row", 0))
    writer.write_i32(mower.get("anim_ticks_per_frame", 0))
    writer.write_u32(mower.get("reanim_id", 0))
    writer.write_i32(mower.get("chomp_counter", 0))
    writer.write_i32(mower.get("rolling_in_counter", 0))
    writer.write_i32(mower.get("squished_counter", 0))
    writer.write_i32(enum_value(MowerState, mower.get("mower_state", "MOWER_READY")))
    writer.write_bool(mower.get("dead", False))
    writer.write_bool(mower.get("visible", True))
    writer.write_i32(enum_value(MowerType, mower.get("mower_type", "MOWER_LAWN")))
    writer.write_f32(mower.get("altitude", 0.0))
    writer.write_i32(mower.get("mower_height", 0))
    writer.write_i32(mower.get("last_portal_x", 0))
    return writer.get_bytes()


# ============================================================================
# GridItem Parsing
# ============================================================================

# NUM_MOTION_TRAIL_FRAMES = 12, each frame = 3 floats (posX, posY, animTime) = 12 bytes
NUM_MOTION_TRAIL_FRAMES = 12


def parse_griditem_tail(data: bytes) -> dict:
    """Parse GridItem tail fields (field 100).
    
    GridItem fields in order:
    - mGridItemType (i32 enum)
    - mGridItemState (i32)
    - mGridX, mGridY (i32)
    - mGridItemCounter, mRenderOrder (i32)
    - mDead (bool)
    - mPosX, mPosY, mGoalX, mGoalY (f32)
    - mGridItemReanimID, mGridItemParticleID (u32 enum)
    - mZombieType, mSeedType, mScaryPotType (i32 enum) - for SCARY_POT
    - mHighlighted (bool)
    - mTransparentCounter, mSunCount (i32)
    - mMotionTrailFrames[12] (each: 3 floats)
    - mMotionTrailCount (i32)
    """
    reader = BinaryReader(data)
    
    grid_item_type = reader.read_i32()
    item: dict[str, Any] = {
        "grid_item_type": enum_name(GridItemType, grid_item_type),
        "grid_item_state": reader.read_i32(),
        "grid_x": reader.read_i32(),
        "grid_y": reader.read_i32(),
        "grid_item_counter": reader.read_i32(),
        "render_order": reader.read_i32(),
        "dead": reader.read_bool(),
        "pos_x": reader.read_f32(),
        "pos_y": reader.read_f32(),
        "goal_x": reader.read_f32(),
        "goal_y": reader.read_f32(),
        "grid_item_reanim_id": reader.read_u32(),
        "grid_item_particle_id": reader.read_u32(),
    }
    
    # Pot contents - important for Vasebreaker mode
    zombie_type = reader.read_i32()
    seed_type = reader.read_i32()
    scary_pot_type = reader.read_i32()
    
    item["zombie_type"] = enum_name(ZombieType, zombie_type)
    item["seed_type"] = enum_name(SeedType, seed_type)
    item["scary_pot_type"] = enum_name(ScaryPotType, scary_pot_type)
    
    item["highlighted"] = reader.read_bool()
    item["transparent_counter"] = reader.read_i32()
    item["sun_count"] = reader.read_i32()
    
    # Motion trail frames - keep as raw data since rarely edited
    motion_data_size = NUM_MOTION_TRAIL_FRAMES * 3 * 4  # 12 frames * 3 floats * 4 bytes
    if reader.remaining >= motion_data_size + 4:
        item["_motion_trail_data"] = base64.b64encode(reader.read_bytes(motion_data_size)).decode('ascii')
        item["motion_trail_count"] = reader.read_i32()
    
    # Any remaining data
    if reader.remaining > 0:
        item["_extra"] = base64.b64encode(reader.read_bytes(reader.remaining)).decode('ascii')
    
    return item


def write_griditem_tail(item: dict) -> bytes:
    """Write GridItem tail fields."""
    writer = BinaryWriter()
    
    writer.write_i32(enum_value(GridItemType, item.get("grid_item_type", "GRIDITEM_NONE")))
    writer.write_i32(item.get("grid_item_state", 0))
    writer.write_i32(item.get("grid_x", 0))
    writer.write_i32(item.get("grid_y", 0))
    writer.write_i32(item.get("grid_item_counter", 0))
    writer.write_i32(item.get("render_order", 0))
    writer.write_bool(item.get("dead", False))
    writer.write_f32(item.get("pos_x", 0.0))
    writer.write_f32(item.get("pos_y", 0.0))
    writer.write_f32(item.get("goal_x", 0.0))
    writer.write_f32(item.get("goal_y", 0.0))
    writer.write_u32(item.get("grid_item_reanim_id", 0))
    writer.write_u32(item.get("grid_item_particle_id", 0))
    
    # Pot contents
    writer.write_i32(enum_value(ZombieType, item.get("zombie_type", "ZOMBIE_INVALID")))
    writer.write_i32(enum_value(SeedType, item.get("seed_type", "SEED_NONE")))
    writer.write_i32(enum_value(ScaryPotType, item.get("scary_pot_type", "SCARYPOT_NONE")))
    
    writer.write_bool(item.get("highlighted", False))
    writer.write_i32(item.get("transparent_counter", 0))
    writer.write_i32(item.get("sun_count", 0))
    
    # Motion trail data
    if "_motion_trail_data" in item:
        writer.write_bytes(base64.b64decode(item["_motion_trail_data"]))
        writer.write_i32(item.get("motion_trail_count", 0))
    else:
        # Write default motion trail data (all zeros)
        motion_data_size = NUM_MOTION_TRAIL_FRAMES * 3 * 4
        writer.write_bytes(b'\x00' * motion_data_size)
        writer.write_i32(0)
    
    if "_extra" in item:
        writer.write_bytes(base64.b64decode(item["_extra"]))
    
    return writer.get_bytes()


# ============================================================================
# SeedBank Parsing
# ============================================================================

def parse_seedbank_tlv(data: bytes) -> dict:
    """Parse SEEDBANK chunk with TLV wrapper."""
    reader = BinaryReader(data)
    blob_size = reader.read_u32()
    blob_data = reader.read_bytes(blob_size)
    
    fields = parse_tlv_fields(blob_data)
    result = {}
    
    # Field 1 = GameObject base
    if 1 in fields:
        result["_base"] = base64.b64encode(fields[1]).decode('ascii')
    
    # Field 100 = SeedBank tail
    if 100 in fields:
        tail_reader = BinaryReader(fields[100])
        result["num_packets"] = tail_reader.read_i32()
        result["cutscene_darken"] = tail_reader.read_i32()
        result["conveyor_belt_counter"] = tail_reader.read_i32()
    
    return result


def write_seedbank_tlv(seedbank: dict) -> bytes:
    """Write SEEDBANK chunk inner data."""
    fields = {}
    
    # Field 1 = GameObject base
    if "_base" in seedbank:
        fields[1] = base64.b64decode(seedbank["_base"])
    
    # Field 100 = SeedBank tail
    writer = BinaryWriter()
    writer.write_i32(seedbank.get("num_packets", 0))
    writer.write_i32(seedbank.get("cutscene_darken", 0))
    writer.write_i32(seedbank.get("conveyor_belt_counter", 0))
    fields[100] = writer.get_bytes()
    
    blob_data = write_tlv_fields(fields)
    result = BinaryWriter()
    result.write_u32(len(blob_data))
    result.write_bytes(blob_data)
    return result.get_bytes()


# ============================================================================
# SeedPacket Parsing
# ============================================================================

def parse_seedpacket_tail(data: bytes) -> dict:
    """Parse SeedPacket tail fields (field 100)."""
    reader = BinaryReader(data)
    return {
        "refresh_counter": reader.read_i32(),
        "refresh_time": reader.read_i32(),
        "index": reader.read_i32(),
        "offset_x": reader.read_i32(),
        "packet_type": enum_name(SeedType, reader.read_i32()),
        "imitater_type": enum_name(SeedType, reader.read_i32()),
        "slot_machine_countdown": reader.read_i32(),
        "slot_machining_next_seed": enum_name(SeedType, reader.read_i32()),
        "slot_machining_position": reader.read_f32(),
        "active": reader.read_bool(),
        "refreshing": reader.read_bool(),
        "times_used": reader.read_i32(),
    }


def write_seedpacket_tail(packet: dict) -> bytes:
    """Write SeedPacket tail fields."""
    writer = BinaryWriter()
    writer.write_i32(packet.get("refresh_counter", 0))
    writer.write_i32(packet.get("refresh_time", 0))
    writer.write_i32(packet.get("index", 0))
    writer.write_i32(packet.get("offset_x", 0))
    writer.write_i32(enum_value(SeedType, packet.get("packet_type", "SEED_NONE")))
    writer.write_i32(enum_value(SeedType, packet.get("imitater_type", "SEED_NONE")))
    writer.write_i32(packet.get("slot_machine_countdown", 0))
    writer.write_i32(enum_value(SeedType, packet.get("slot_machining_next_seed", "SEED_NONE")))
    writer.write_f32(packet.get("slot_machining_position", 0.0))
    writer.write_bool(packet.get("active", False))
    writer.write_bool(packet.get("refreshing", False))
    writer.write_i32(packet.get("times_used", 0))
    return writer.get_bytes()


def parse_seedpackets(data: bytes) -> list[dict[str, Any]]:
    """Parse SEEDPACKETS chunk (special format: count + items)."""
    reader = BinaryReader(data)
    count = reader.read_i32()
    
    packets: list[dict[str, Any]] = []
    for i in range(count):
        if reader.remaining < 4:
            break
        item_size = reader.read_u32()
        if reader.remaining < item_size:
            break
        item_data = reader.read_bytes(item_size)
        
        item_fields = parse_tlv_fields(item_data)
        packet: dict[str, Any] = {"_index": i}
        
        # Field 1 = GameObject base
        if 1 in item_fields:
            packet["_base"] = base64.b64encode(item_fields[1]).decode('ascii')
        
        # Field 100 = SeedPacket tail
        if 100 in item_fields:
            try:
                tail = parse_seedpacket_tail(item_fields[100])
                packet.update(tail)
            except Exception:
                packet["_tail_raw"] = base64.b64encode(item_fields[100]).decode('ascii')
        
        packets.append(packet)
    
    return packets


def write_seedpackets(packets: list) -> bytes:
    """Write SEEDPACKETS chunk inner data."""
    writer = BinaryWriter()
    writer.write_i32(len(packets))
    
    for packet in packets:
        fields = {}
        
        # Field 1 = GameObject base
        if "_base" in packet:
            fields[1] = base64.b64decode(packet["_base"])
        
        # Field 100 = SeedPacket tail
        if "_tail_raw" in packet:
            fields[100] = base64.b64decode(packet["_tail_raw"])
        else:
            fields[100] = write_seedpacket_tail(packet)
        
        item_data = write_tlv_fields(fields)
        writer.write_u32(len(item_data))
        writer.write_bytes(item_data)
    
    return writer.get_bytes()


# ============================================================================
# Challenge Parsing
# ============================================================================

def parse_challenge_tlv(data: bytes) -> dict:
    """Parse CHALLENGE chunk with TLV wrapper."""
    reader = BinaryReader(data)
    blob_size = reader.read_u32()
    blob_data = reader.read_bytes(blob_size)
    
    fields = parse_tlv_fields(blob_data)
    result = {}
    
    # Field 100 = Challenge tail - keep as raw for now (too complex)
    if 100 in fields:
        result["_data"] = base64.b64encode(fields[100]).decode('ascii')
    
    return result


def write_challenge_tlv(challenge: dict) -> bytes:
    """Write CHALLENGE chunk inner data."""
    fields = {}
    
    if "_data" in challenge:
        fields[100] = base64.b64decode(challenge["_data"])
    
    blob_data = write_tlv_fields(fields)
    result = BinaryWriter()
    result.write_u32(len(blob_data))
    result.write_bytes(blob_data)
    return result.get_bytes()


# ============================================================================
# Generic Object Array Parsing
# ============================================================================

def parse_object_array(data: bytes, tail_parser, obj_name: str) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    """Parse a DataArray of game objects. Returns (header_dict, items_list)."""
    header, items = parse_data_array_tlv(data)
    
    header_dict: dict[str, Any] = {
        "free_list_head": header.free_list_head,
        "max_used_count": header.max_used_count,
        "size": header.size,
        "next_key": header.next_key,
        "max_size": header.max_size,
    }
    
    objects: list[dict[str, Any]] = []
    DATA_ARRAY_KEY_MASK = 0xFFFFFF00
    
    for item in items:
        obj: dict[str, Any] = {"_id": item.item_id}
        
        # Check if item is active
        is_active = (item.item_id & DATA_ARRAY_KEY_MASK) != 0
        
        # Field 1 = GameObject base
        if 1 in item.fields:
            obj["_base"] = parse_game_object(item.fields[1])
        
        # Field 100 = tail fields
        if 100 in item.fields:
            if is_active:
                try:
                    tail = tail_parser(item.fields[100])
                    obj.update(tail)
                except Exception as e:
                    obj["_tail_raw"] = base64.b64encode(item.fields[100]).decode('ascii')
            else:
                # Inactive items - keep raw
                obj["_tail_raw"] = base64.b64encode(item.fields[100]).decode('ascii')
        
        # Any other fields
        for fid, fdata in item.fields.items():
            if fid not in (1, 100):
                obj[f"_field_{fid}"] = base64.b64encode(fdata).decode('ascii')
        
        objects.append(obj)
    
    return header_dict, objects


def write_object_array(header_dict: dict, objects: list, tail_writer) -> bytes:
    """Write a DataArray of game objects."""
    header = DataArrayHeader(
        free_list_head=header_dict.get("free_list_head", 0),
        max_used_count=header_dict.get("max_used_count", 0),
        size=header_dict.get("size", 0),
        next_key=header_dict.get("next_key", 0),
        max_size=header_dict.get("max_size", 0),
    )
    
    DATA_ARRAY_KEY_MASK = 0xFFFFFF00
    items = []
    for obj in objects:
        item_id = obj.get("_id", 0)
        is_active = (item_id & DATA_ARRAY_KEY_MASK) != 0
        
        fields = {}
        
        # Field 1 = GameObject base
        if "_base" in obj:
            fields[1] = write_game_object(obj["_base"])
        
        # Field 100 = tail fields
        # Only write tail data if object has it (active objects have tail data)
        if "_tail_raw" in obj:
            fields[100] = base64.b64decode(obj["_tail_raw"])
        elif is_active:
            # Active object with parsed fields - reconstruct tail
            fields[100] = tail_writer(obj)
        # Inactive objects without _tail_raw: no field 100 data
        
        # Any other fields
        for key, value in obj.items():
            if key.startswith("_field_"):
                fid = int(key.split("_")[-1])
                fields[fid] = base64.b64decode(value)
        
        item_data = write_tlv_fields(fields)
        items.append(DataArrayItem(item_id=item_id, data=item_data))
    
    return write_data_array_tlv(header, items)


# ============================================================================
# Main Save File Structure
# ============================================================================

@dataclass
class SaveFile:
    """Represents a parsed v4 save file."""
    version: int = SAVE_VERSION
    chunk_order: list = field(default_factory=list)  # Preserve original order
    
    # Parsed readable chunks
    board: dict = field(default_factory=dict)
    zombies_header: dict = field(default_factory=dict)
    zombies: list = field(default_factory=list)
    plants_header: dict = field(default_factory=dict)
    plants: list = field(default_factory=list)
    mowers_header: dict = field(default_factory=dict)
    mowers: list = field(default_factory=list)
    griditems_header: dict = field(default_factory=dict)
    griditems: list = field(default_factory=list)
    seedbank: dict = field(default_factory=dict)
    seedpackets: list = field(default_factory=list)
    challenge: dict = field(default_factory=dict)
    
    # Binary chunks (base64 encoded)
    binary_chunks: dict = field(default_factory=dict)


def parse_save_file(data: bytes) -> SaveFile:
    """Parse a v4 save file."""
    if len(data) < HEADER_SIZE:
        print(f"Error: File is too small ({len(data)} bytes). Expected at least {HEADER_SIZE} bytes.")
        print("This does not appear to be a valid PvZ-Portable save file.")
        sys.exit(1)

    # Parse header: magic(12) + version(4) + payloadSize(4) + payloadCrc(4)
    magic = data[:12]
    expected_magic_base = b"PVZP_SAVE"
    
    if not magic.startswith(expected_magic_base):
        print(f"Error: Invalid file format.")
        print(f"Expected magic starting with '{expected_magic_base.decode()}', got '{magic[:9].decode(errors='replace')}'")
        sys.exit(1)
        
    if not magic.startswith(b"PVZP_SAVE4"):
        # Try to detect version from magic
        try:
            version_char = magic[9:10]
            if version_char.isdigit():
                found_version = int(version_char)
                print(f"Error: Format version mismatch.")
                print(f"This tool only supports v4 save files (PVZP_SAVE4).")
                print(f"Found v{found_version} save file (PVZP_SAVE{found_version}).")
            else:
                print(f"Error: Unknown magic format: {magic!r}")
        except Exception:
            print(f"Error: Invalid magic: {magic!r}")
        sys.exit(1)
    
    version = struct.unpack("<I", data[12:16])[0]
    if version != SAVE_VERSION:
        print(f"Warning: File header says version {version}, but script expects version {SAVE_VERSION}.")
        print("Proceeding anyway, but errors may occur.")
    
    payload_size = struct.unpack("<I", data[16:20])[0]
    stored_crc = struct.unpack("<I", data[20:24])[0]
    
    payload = data[24:24 + payload_size]
    calculated_crc = zlib.crc32(payload) & 0xFFFFFFFF
    if stored_crc != calculated_crc:
        raise ValueError(f"CRC mismatch: stored {stored_crc:08x}, calculated {calculated_crc:08x}")
    
    # Parse chunks
    save = SaveFile(version=version)
    reader = BinaryReader(payload)
    
    while reader.remaining >= 8:
        chunk_type = reader.read_u32()
        chunk_size = reader.read_u32()
        if reader.remaining < chunk_size:
            break
        chunk_data = reader.read_bytes(chunk_size)
        
        try:
            chunk_name = ChunkType(chunk_type).name
        except ValueError:
            chunk_name = f"UNKNOWN_{chunk_type}"
        
        save.chunk_order.append(chunk_type)
        
        # Each chunk has internal structure:
        # - chunk_version (4 bytes)
        # - field_id (4 bytes) = 1
        # - field_size (4 bytes)
        # - actual data
        try:
            chunk_reader = BinaryReader(chunk_data)
            chunk_version = chunk_reader.read_u32()
            if chunk_version != 1:
                save.binary_chunks[chunk_name] = base64.b64encode(chunk_data).decode('ascii')
                continue
            
            # Read the TLV wrapper inside chunk
            if chunk_reader.remaining < 8:
                save.binary_chunks[chunk_name] = base64.b64encode(chunk_data).decode('ascii')
                continue
                
            field_id = chunk_reader.read_u32()
            field_size = chunk_reader.read_u32()
            if field_id != 1 or chunk_reader.remaining < field_size:
                save.binary_chunks[chunk_name] = base64.b64encode(chunk_data).decode('ascii')
                continue
            inner_data = chunk_reader.read_bytes(field_size)
            
            # Parse based on chunk type
            if chunk_type == ChunkType.BOARD_BASE:
                save.board = parse_board_base(inner_data)
            elif chunk_type == ChunkType.ZOMBIES:
                save.zombies_header, save.zombies = parse_object_array(inner_data, parse_zombie_tail, "zombie")
            elif chunk_type == ChunkType.PLANTS:
                save.plants_header, save.plants = parse_object_array(inner_data, parse_plant_tail, "plant")
            elif chunk_type == ChunkType.MOWERS:
                save.mowers_header, save.mowers = parse_object_array(inner_data, parse_mower_tail, "mower")
            elif chunk_type == ChunkType.GRIDITEMS:
                save.griditems_header, save.griditems = parse_object_array(inner_data, parse_griditem_tail, "griditem")
            elif chunk_type == ChunkType.SEEDBANK:
                save.seedbank = parse_seedbank_tlv(inner_data)
            elif chunk_type == ChunkType.SEEDPACKETS:
                save.seedpackets = parse_seedpackets(inner_data)
            elif chunk_type == ChunkType.CHALLENGE:
                save.challenge = parse_challenge_tlv(inner_data)
            else:
                # Keep as binary
                save.binary_chunks[chunk_name] = base64.b64encode(chunk_data).decode('ascii')
        except Exception as e:
            print(f"Warning: Failed to parse {chunk_name}: {e}, keeping as binary", file=sys.stderr)
            save.binary_chunks[chunk_name] = base64.b64encode(chunk_data).decode('ascii')
    
    return save


def write_chunk(chunk_type: int, inner_data: bytes) -> bytes:
    """Wrap inner data in chunk format."""
    # Chunk format: version(4) + field_id(4) + field_size(4) + data
    writer = BinaryWriter()
    writer.write_u32(1)  # chunk version
    writer.write_u32(1)  # field id
    writer.write_u32(len(inner_data))
    writer.write_bytes(inner_data)
    return writer.get_bytes()


def write_save_file(save: SaveFile) -> bytes:
    """Write a v4 save file."""
    # Build payload
    payload = BinaryWriter()
    
    for chunk_type in save.chunk_order:
        try:
            chunk_name = ChunkType(chunk_type).name
        except ValueError:
            chunk_name = f"UNKNOWN_{chunk_type}"
        
        chunk_data = None
        
        # Check binary chunks first
        if chunk_name in save.binary_chunks:
            chunk_data = base64.b64decode(save.binary_chunks[chunk_name])
        elif chunk_type == ChunkType.BOARD_BASE:
            inner = write_board_base(save.board)
            chunk_data = write_chunk(chunk_type, inner)
        elif chunk_type == ChunkType.ZOMBIES:
            inner = write_object_array(save.zombies_header, save.zombies, write_zombie_tail)
            chunk_data = write_chunk(chunk_type, inner)
        elif chunk_type == ChunkType.PLANTS:
            inner = write_object_array(save.plants_header, save.plants, write_plant_tail)
            chunk_data = write_chunk(chunk_type, inner)
        elif chunk_type == ChunkType.MOWERS:
            inner = write_object_array(save.mowers_header, save.mowers, write_mower_tail)
            chunk_data = write_chunk(chunk_type, inner)
        elif chunk_type == ChunkType.GRIDITEMS:
            inner = write_object_array(save.griditems_header, save.griditems, write_griditem_tail)
            chunk_data = write_chunk(chunk_type, inner)
        elif chunk_type == ChunkType.SEEDBANK:
            inner = write_seedbank_tlv(save.seedbank)
            chunk_data = write_chunk(chunk_type, inner)
        elif chunk_type == ChunkType.SEEDPACKETS:
            inner = write_seedpackets(save.seedpackets)
            chunk_data = write_chunk(chunk_type, inner)
        elif chunk_type == ChunkType.CHALLENGE:
            inner = write_challenge_tlv(save.challenge)
            chunk_data = write_chunk(chunk_type, inner)
        
        if chunk_data:
            payload.write_u32(chunk_type)
            payload.write_u32(len(chunk_data))
            payload.write_bytes(chunk_data)
    
    payload_bytes = payload.get_bytes()
    payload_crc = zlib.crc32(payload_bytes) & 0xFFFFFFFF
    
    # Build file
    result = BinaryWriter()
    result.write_bytes(SAVE_MAGIC)
    result.write_u32(save.version)
    result.write_u32(len(payload_bytes))
    result.write_u32(payload_crc)
    result.write_bytes(payload_bytes)
    
    return result.get_bytes()


# ============================================================================
# YAML Export/Import
# ============================================================================

def export_to_yaml(save: SaveFile) -> str:
    """Export save file to YAML format (lossless)."""
    output = {
        "_format": "PvZ-Portable Save v4",
        "_version": save.version,
        "_chunk_order": save.chunk_order,
        "board": save.board,
        "zombies_header": save.zombies_header,
        "zombies": save.zombies,
        "plants_header": save.plants_header,
        "plants": save.plants,
        "mowers_header": save.mowers_header,
        "mowers": save.mowers,
        "griditems_header": save.griditems_header,
        "griditems": save.griditems,
        "seedbank": save.seedbank,
        "seedpackets": save.seedpackets,
        "challenge": save.challenge,
        "binary_chunks": save.binary_chunks,
    }
    
    return yaml.dump(output, allow_unicode=True, sort_keys=False, default_flow_style=False, width=120)


def import_from_yaml(yaml_str: str) -> SaveFile:
    """Import YAML and create SaveFile."""
    data = yaml.safe_load(yaml_str)
    
    save = SaveFile(
        version=data.get("_version", SAVE_VERSION),
        chunk_order=data.get("_chunk_order", []),
        board=data.get("board", {}),
        zombies_header=data.get("zombies_header", {}),
        zombies=data.get("zombies", []),
        plants_header=data.get("plants_header", {}),
        plants=data.get("plants", []),
        mowers_header=data.get("mowers_header", {}),
        mowers=data.get("mowers", []),
        griditems_header=data.get("griditems_header", {}),
        griditems=data.get("griditems", []),
        seedbank=data.get("seedbank", {}),
        seedpackets=data.get("seedpackets", []),
        challenge=data.get("challenge", {}),
        binary_chunks=data.get("binary_chunks", {}),
    )
    
    return save


# ============================================================================
# Text Export (info command)
# ============================================================================

def export_to_text(save: SaveFile) -> str:
    """Export save file to human-readable text format (summary only)."""
    lines = []
    lines.append("=" * 60)
    lines.append("PvZ-Portable Mid-Level Save File (v4 Format)")
    lines.append("=" * 60)
    lines.append("")
    
    # Board info
    lines.append("[Game State]")
    lines.append(f"  Level: {save.board.get('level', 0)}")
    lines.append(f"  Background: {save.board.get('background', 'UNKNOWN')}")
    lines.append(f"  Sun: {save.board.get('sun_money', 0)}")
    lines.append(f"  Current Wave: {save.board.get('current_wave', 0)} / {save.board.get('num_waves', 0)}")
    lines.append(f"  Paused: {'Yes' if save.board.get('paused') else 'No'}")
    lines.append(f"  Level Complete: {'Yes' if save.board.get('level_complete') else 'No'}")
    lines.append("")
    
    # Seed packets
    lines.append("[Seed Slots]")
    num_slots = save.seedbank.get("num_packets", 0)
    if num_slots > 0 and save.seedpackets:
        # Display all seed packets up to num_packets count
        for i, packet in enumerate(save.seedpackets[:num_slots]):
            seed_type = packet.get("packet_type", "UNKNOWN")
            try:
                st = SeedType[seed_type]
                name = PLANT_NAMES.get(st, seed_type)
            except (KeyError, ValueError):
                name = seed_type
            # Determine status: active=False means still in initial cooldown
            if packet.get("refreshing") or not packet.get("active"):
                refresh_counter = packet.get("refresh_counter", 0)
                refresh_time = packet.get("refresh_time", 1)
                # Convert from centiseconds to seconds for display
                counter_sec = refresh_counter / 100.0
                time_sec = refresh_time / 100.0
                status = f"Recharging {counter_sec:.2f}s/{time_sec:.2f}s"
            else:
                status = "Ready"
            lines.append(f"  [{i+1}] {name} ({status})")
    else:
        lines.append("  (None)")
    lines.append("")
    
    # Plants
    lines.append("[Plants on Field]")
    DATA_ARRAY_KEY_MASK = 0xFFFFFF00
    live_plants = [p for p in save.plants 
                   if not p.get("dead") and (p.get("_id", 0) & DATA_ARRAY_KEY_MASK) != 0]
    if live_plants:
        for plant in live_plants:
            base = plant.get("_base", {})
            seed_type = plant.get("seed_type", "UNKNOWN")
            try:
                st = SeedType[seed_type]
                name = PLANT_NAMES.get(st, seed_type)
            except (KeyError, ValueError):
                name = seed_type
            row = base.get("row", -1)
            col = plant.get("plant_col", -1)
            health = plant.get("plant_health", 0)
            max_health = plant.get("plant_max_health", 0)
            asleep_label = " (Asleep)" if plant.get("is_asleep") else ""
            lines.append(f"  [{row}, {col}] {name}{asleep_label} (HP: {health}/{max_health})")
    else:
        lines.append("  (None)")
    lines.append("")
    
    # Zombies
    lines.append("[Zombies on Field]")
    live_zombies = [z for z in save.zombies 
                    if not z.get("dead") and (z.get("_id", 0) & DATA_ARRAY_KEY_MASK) != 0]
    if live_zombies:
        for zombie in live_zombies:
            base = zombie.get("_base", {})
            zombie_type = zombie.get("zombie_type", "UNKNOWN")
            try:
                zt = ZombieType[zombie_type]
                name = ZOMBIE_NAMES.get(zt, zombie_type)
            except (KeyError, ValueError):
                name = zombie_type
            row = base.get("row", -1)
            pos_x = zombie.get("pos_x", 0)
            body_health = zombie.get("body_health", 0)
            # Build status labels
            status_labels = []
            if zombie.get("mind_controlled"):
                status_labels.append("Hypnotized")
            if zombie.get("ice_trap_counter", 0) > 0:
                status_labels.append("Frozen")
            elif zombie.get("chilled_counter", 0) > 0:
                status_labels.append("Chilled")
            if zombie.get("buttered_counter", 0) > 0:
                status_labels.append("Buttered")
            if zombie.get("blowing_away"):
                status_labels.append("Blowing")
            if zombie.get("is_eating"):
                status_labels.append("Eating")
            status_str = f" [{', '.join(status_labels)}]" if status_labels else ""
            lines.append(f"  [Row {row}] {name}{status_str} (HP: {body_health}, X: {pos_x:.0f})")
    else:
        lines.append("  (None)")
    lines.append("")
    
    # Mowers
    lines.append("[Lawn Mowers]")
    active_mowers = [m for m in save.mowers 
                     if not m.get("dead") and (m.get("_id", 0) & DATA_ARRAY_KEY_MASK) != 0]
    if active_mowers:
        for mower in active_mowers:
            row = mower.get("row", -1)
            mower_type = mower.get("mower_type", "MOWER_LAWN")
            state = mower.get("mower_state", "MOWER_READY")
            lines.append(f"  [Row {row}] {mower_type} ({state})")
    else:
        lines.append("  (None)")
    lines.append("")
    
    # Stats
    lines.append("[Statistics]")
    lines.append(f"  Coins Collected: {save.board.get('coins_collected', 0)}")
    lines.append(f"  Diamonds Collected: {save.board.get('diamonds_collected', 0)}")
    lines.append(f"  Plants Eaten: {save.board.get('plants_eaten', 0)}")
    lines.append(f"  Graves Cleared: {save.board.get('graves_cleared', 0)}")
    
    return "\n".join(lines)


# ============================================================================
# CLI
# ============================================================================

def cmd_info(args):
    """Show save file information."""
    save_path = Path(args.input)
    if not save_path.exists():
        print(f"Error: File not found: {save_path}", file=sys.stderr)
        return 1
    
    try:
        data = save_path.read_bytes()
        save = parse_save_file(data)
        print(export_to_text(save))
        return 0
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1


def cmd_export(args):
    """Export save file to YAML."""
    save_path = Path(args.input)
    output_path = Path(args.output)
    
    if not save_path.exists():
        print(f"Error: File not found: {save_path}", file=sys.stderr)
        return 1
    
    try:
        data = save_path.read_bytes()
        save = parse_save_file(data)
        
        output = export_to_yaml(save)
        output_path.write_text(output, encoding="utf-8")
        print(f"Exported to: {output_path}")
        return 0
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1


def cmd_import(args):
    """Import YAML and generate v4 save."""
    yaml_path = Path(args.input)
    output_path = Path(args.output)
    
    if not yaml_path.exists():
        print(f"Error: File not found: {yaml_path}", file=sys.stderr)
        return 1
    
    try:
        yaml_str = yaml_path.read_text(encoding="utf-8")
        save = import_from_yaml(yaml_str)
        data = write_save_file(save)
        output_path.write_bytes(data)
        print(f"Imported to: {output_path}")
        return 0
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return 1


def main():
    global EXPAND_ZOMBIES_IN_WAVE
    
    parser = argparse.ArgumentParser(
        description="PvZ-Portable Mid-Level Save File Converter for v4 Format",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s info game1.v4                   Show save file information
  %(prog)s export game1.v4 game1.yaml      Export to YAML format (lossless)
  %(prog)s export --expand-waves game1.v4 game1.yaml  Export with expanded wave data
  %(prog)s import game1.yaml game1_new.v4  Import YAML back to v4 format

This converter is LOSSLESS - the YAML contains all data needed to
recreate an identical v4 save file. Human-readable fields can be
edited, while complex binary data is preserved as base64.
"""
    )
    subparsers = parser.add_subparsers(dest="command", required=True)
    
    # info command
    info_parser = subparsers.add_parser("info", help="Show save file information")
    info_parser.add_argument("input", help="Input v4 save file")
    info_parser.set_defaults(func=cmd_info)
    
    # export command
    export_parser = subparsers.add_parser("export", help="Export save to YAML format (lossless)")
    export_parser.add_argument("input", help="Input v4 save file")
    export_parser.add_argument("output", help="Output YAML file")
    export_parser.add_argument("--expand-waves", action="store_true",
                               help="Expand zombies_in_wave to human-readable list")
    export_parser.set_defaults(func=cmd_export)
    
    # import command
    import_parser = subparsers.add_parser("import", help="Import YAML and generate v4 save")
    import_parser.add_argument("input", help="Input YAML file")
    import_parser.add_argument("output", help="Output v4 save file")
    import_parser.set_defaults(func=cmd_import)
    
    args = parser.parse_args()
    
    # Set global options
    if hasattr(args, 'expand_waves') and args.expand_waves:
        EXPAND_ZOMBIES_IN_WAVE = True
    
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
