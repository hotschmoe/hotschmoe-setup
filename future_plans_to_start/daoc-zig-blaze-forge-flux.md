# Dark Age of Camelot Recreation in Pure Zig
## Built on BLAZE/FORGE/FLUX Graphics Stack
### A Technical Deep Dive for Hobby Development

---

## Executive Summary

Dark Age of Camelot (2001) was a technical marvel for its time - a 3-realm MMORPG that handled thousands of concurrent players per server cluster using surprisingly modest resources. Recreating it in pure Zig offers a unique opportunity to leverage modern language features (comptime, manual memory control, zero-cost abstractions) while targeting the original's visual fidelity and dramatically improving performance.

**What's New in This Design:**
- **BLAZE** - GPU abstraction layer (Vulkan 1.3+)
- **FORGE** - 3D scene rendering (GPU-driven, meshlets, terrain)
- **FLUX** - UI framework (hotbars, chat, inventory, map)
- **EMBER** - Game framework extracted from this project (reusable for other MMOs)

The goal: Build DAoC, then extract the reusable parts into a Zig game framework.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              DAOC-ZIG                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                           CLIENT                                         ││
│  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────────────────────┐││
│  │  │   Game Logic  │  │    Input      │  │         Network               │││
│  │  │  - Prediction │  │  - Keyboard   │  │  - Server connection          │││
│  │  │  - Interp     │  │  - Mouse      │  │  - Packet encode/decode       │││
│  │  │  - Animation  │  │  - Gamepad    │  │  - State sync                 │││
│  │  └───────┬───────┘  └───────┬───────┘  └───────────────┬───────────────┘││
│  │          │                  │                          │                 ││
│  │          └──────────────────┼──────────────────────────┘                 ││
│  │                             │                                            ││
│  │                             ▼                                            ││
│  │  ┌─────────────────────────────────────────────────────────────────────┐││
│  │  │                      EMBER (Game Framework)                          │││
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │││
│  │  │  │    ECS      │  │   Assets    │  │    Audio    │  │   Scene     │ │││
│  │  │  │  (shared)   │  │   Manager   │  │   System    │  │   Graph     │ │││
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘ │││
│  │  └─────────────────────────────────────────────────────────────────────┘││
│  │                             │                                            ││
│  │          ┌──────────────────┼──────────────────┐                         ││
│  │          ▼                  ▼                  ▼                         ││
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                   ││
│  │  │    FORGE    │    │    FLUX     │    │   BLAZE     │                   ││
│  │  │  3D Scene   │    │     UI      │    │  GPU Core   │                   ││
│  │  │  Rendering  │    │  Framework  │    │  (Vulkan)   │                   ││
│  │  └─────────────┘    └─────────────┘    └─────────────┘                   ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                           SERVER                                         ││
│  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────────────────────┐││
│  │  │   World Sim   │  │    Network    │  │         Database              │││
│  │  │  - ECS        │  │  - io_uring   │  │  - SQLite                     │││
│  │  │  - Combat     │  │  - Packets    │  │  - Characters                 │││
│  │  │  - AI         │  │  - Sessions   │  │  - Items                      │││
│  │  └───────────────┘  └───────────────┘  └───────────────────────────────┘││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                           COMMON                                         ││
│  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────────────────────┐││
│  │  │     ECS       │  │    Network    │  │         Game Data             │││
│  │  │  Components   │  │   Protocol    │  │  - Spells (comptime)          │││
│  │  │  Archetypes   │  │   Packets     │  │  - Classes (comptime)         │││
│  │  │               │  │   Opcodes     │  │  - Items (comptime)           │││
│  │  └───────────────┘  └───────────────┘  └───────────────────────────────┘││
│  └─────────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Part 1: Understanding the Original Architecture

### Server Infrastructure (What We're Recreating)

The original DAoC architecture (per Wikipedia and the Mythic postmortem):

- **6 servers per "world"** - designed for 20,000 concurrent players, throttled to ~4,000
- **Thin client design** - most game logic ran server-side
- **~10 kbit/s per player** - remarkably low bandwidth budget
- **Linux/Open Source backend** - they ran on commodity hardware with open-source software
- **Development cost**: ~$2.5M over 18 months with 25 developers

### What OpenDAoC Taught Us

The modern [OpenDAoC](https://github.com/OpenDAoC/OpenDAoC-Core) emulator (C#) provides critical insights:

1. **ECS rewrite was essential** - They completely rewrote DOLSharp with ECS architecture for scalability
2. **Patch-level targeting** - Focused on 1.65 era, but architecture supports any patch
3. **~12,700 commits** - Shows the scope of work involved

### Packet Structure (From Security Research)

From the 2003 security advisory and Eve of Darkness documentation:

```
TCP Login Packet Format:
+------+------+-------------+--------------+
| 0x1b | 0x1b | Payload Len | Payload Data |
+------+------+-------------+--------------+
| ESC  | ESC  |  2 bytes    |   Variable   |

Client Payload:
+---------+---------+----------------------+
| Opcode  |    ?    | Opcode-specific data |
+---------+---------+----------------------+
| 2 bytes | 2 bytes | Payload Len - 4      |

Server Payload:
+---------+----------------------+
| Opcode  | Opcode-specific data |
+---------+----------------------+
| 2 bytes | Payload len - 2      |
```

**All integers are network byte order (big-endian).**

---

## Part 2: Project Structure

```
daoc-zig/
├── build.zig
├── src/
│   ├── common/                    # Shared code between client/server
│   │   ├── ecs/                  # Entity Component System
│   │   │   ├── world.zig
│   │   │   ├── archetype.zig
│   │   │   └── components/
│   │   │       ├── position.zig
│   │   │       ├── combat.zig
│   │   │       ├── character.zig
│   │   │       └── ...
│   │   ├── net/                  # Packet definitions, serialization
│   │   │   ├── protocol.zig
│   │   │   ├── packets/
│   │   │   └── opcodes.zig
│   │   ├── game/                 # Game rules, formulas, data
│   │   │   ├── combat.zig
│   │   │   ├── spells.zig
│   │   │   └── classes.zig
│   │   └── math/                 # 3D math, collision
│   │       ├── vec3.zig
│   │       └── collision.zig
│   │
│   ├── server/
│   │   ├── main.zig
│   │   ├── world/               # Zone management, spawns
│   │   ├── combat/              # Damage calculation, styles
│   │   ├── ai/                  # NPC behavior
│   │   ├── db/                  # Database layer
│   │   └── net/                 # Server networking (io_uring)
│   │
│   ├── client/
│   │   ├── main.zig
│   │   ├── game/                # Client-side game logic
│   │   │   ├── prediction.zig
│   │   │   ├── interpolation.zig
│   │   │   └── animation.zig
│   │   ├── scene/               # FORGE integration
│   │   │   ├── world_renderer.zig
│   │   │   ├── character_renderer.zig
│   │   │   ├── terrain.zig
│   │   │   └── effects.zig
│   │   ├── ui/                  # FLUX integration
│   │   │   ├── hud.zig
│   │   │   ├── chat.zig
│   │   │   ├── inventory.zig
│   │   │   ├── spellbar.zig
│   │   │   └── map.zig
│   │   ├── audio/               # Sound system
│   │   └── net/                 # Client networking
│   │
│   └── ember/                   # Game Framework (extracted)
│       ├── app.zig              # Application lifecycle
│       ├── scene.zig            # Scene graph
│       ├── assets.zig           # Asset management
│       └── audio.zig            # Audio system
│
├── libs/
│   ├── blaze/                   # GPU abstraction
│   ├── forge/                   # 3D rendering
│   └── flux/                    # UI framework
│
├── data/
│   ├── spells/                  # Spell definitions (comptime loaded)
│   ├── classes/                 # Class stats and abilities
│   ├── items/                   # Item database
│   ├── zones/                   # Zone geometry, spawn data
│   └── npc/                     # NPC templates
│
├── assets/
│   ├── models/                  # Character/NPC models
│   ├── textures/                # Textures and atlases
│   ├── terrain/                 # Heightmaps, splatmaps
│   ├── shaders/                 # WGSL shaders
│   └── ui/                      # UI textures, fonts
│
└── tools/
    ├── asset_converter/         # Convert original DAoC assets
    ├── zone_editor/             # Zone editing tools
    └── model_viewer/            # Debug tool for models
```

---

## Part 3: BLAZE/FORGE/FLUX Integration

### Graphics Stack Roles

| Layer | Responsibility | DAoC Usage |
|-------|----------------|------------|
| **BLAZE** | Vulkan abstraction, command encoding, memory | All GPU operations |
| **FORGE** | 3D scene rendering, GPU culling, terrain | World, characters, effects |
| **FLUX** | 2D UI, text, input handling | HUD, chat, inventory, map |

### Client Rendering Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Frame Rendering                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  1. Update Phase (CPU)                                                       │
│     ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                    │
│     │ Network Recv │→ │ State Update │→ │ Animation    │                    │
│     │  (packets)   │  │ (interp/pred)│  │  Advance     │                    │
│     └──────────────┘  └──────────────┘  └──────────────┘                    │
│                                                                              │
│  2. Scene Build Phase (CPU → GPU Upload)                                     │
│     ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                    │
│     │ FORGE Scene  │→ │ Object Buffer│→ │ GPU Upload   │                    │
│     │  Update      │  │  Build       │  │ (transforms) │                    │
│     └──────────────┘  └──────────────┘  └──────────────┘                    │
│                                                                              │
│  3. GPU Render Phase                                                         │
│     ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│     │ GPU Culling  │→ │ Depth Pre-   │→ │ Main Pass    │→ │ Post Process │ │
│     │ (compute)    │  │ pass         │  │ (opaque)     │  │ (bloom, etc) │ │
│     └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘ │
│                              │                                               │
│                              ▼                                               │
│     ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                    │
│     │ Transparent  │→ │ Particles/   │→ │ UI Pass      │                    │
│     │ Pass         │  │ Effects      │  │ (FLUX)       │                    │
│     └──────────────┘  └──────────────┘  └──────────────┘                    │
│                                                                              │
│  4. Present                                                                  │
│     └─────────────────────────────────────────────────────→ Swapchain       │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Part 4: FORGE - 3D Scene Rendering

### World Renderer

FORGE handles all 3D rendering with GPU-driven techniques:

```zig
// client/scene/world_renderer.zig

const std = @import("std");
const forge = @import("forge");
const blaze = @import("blaze");
const ecs = @import("../../common/ecs/world.zig");

pub const WorldRenderer = struct {
    allocator: std.mem.Allocator,
    scene: forge.Scene,
    
    // Render categories
    terrain: TerrainRenderer,
    characters: CharacterRenderer,
    objects: StaticObjectRenderer,
    effects: EffectRenderer,
    sky: SkyRenderer,
    water: WaterRenderer,
    
    // Camera
    camera: forge.Camera,
    
    pub fn init(allocator: std.mem.Allocator, ctx: *blaze.Context) !WorldRenderer {
        // Configure FORGE scene for MMO-scale rendering
        const scene = try forge.Scene.init(ctx, .{
            .max_objects = 50_000,          // Characters, NPCs, objects in view
            .max_draw_calls = 10_000,        // After batching
            .features = .{
                .shadows = true,
                .bloom = true,
                .ssao = false,               // Skip for WoW-style aesthetic
                .gpu_culling = true,
            },
            .shadow_cascade_count = 3,
            .shadow_resolution = 2048,
        });
        
        return .{
            .allocator = allocator,
            .scene = scene,
            .terrain = try TerrainRenderer.init(allocator, ctx),
            .characters = try CharacterRenderer.init(allocator, ctx, &scene),
            .objects = try StaticObjectRenderer.init(allocator, ctx, &scene),
            .effects = try EffectRenderer.init(allocator, ctx),
            .sky = try SkyRenderer.init(ctx),
            .water = try WaterRenderer.init(ctx),
            .camera = forge.Camera.perspective(
                std.math.degreesToRadians(60.0),
                16.0 / 9.0,
                0.1,
                10000.0,
            ),
        };
    }
    
    /// Sync ECS world state to FORGE scene
    pub fn syncFromEcs(self: *WorldRenderer, world: *ecs.World, local_player: ?ecs.Entity) void {
        // Update camera from local player
        if (local_player) |player| {
            const pos = player.get(ecs.Position);
            const camera_state = player.get(CameraState);
            
            self.camera.setPosition(.{
                pos.x,
                pos.y + 2.0,  // Eye height
                pos.z,
            });
            self.camera.setRotation(camera_state.pitch, camera_state.yaw);
        }
        
        // Sync character transforms
        var char_iter = world.query(&.{ ecs.Position, ecs.Renderable, ecs.Character });
        while (char_iter.next()) |entity| {
            const pos = entity.get(ecs.Position);
            const renderable = entity.get(ecs.Renderable);
            
            self.characters.updateTransform(renderable.render_id, .{
                .position = .{ pos.x, pos.y, pos.z },
                .rotation = headingToQuat(pos.heading),
                .scale = .{ 1, 1, 1 },
            });
            
            // Update animation state
            if (entity.getOpt(ecs.Animation)) |anim| {
                self.characters.updateAnimation(renderable.render_id, anim);
            }
        }
        
        // Sync NPCs
        var npc_iter = world.query(&.{ ecs.Position, ecs.Renderable, ecs.NpcAi });
        while (npc_iter.next()) |entity| {
            const pos = entity.get(ecs.Position);
            const renderable = entity.get(ecs.Renderable);
            
            self.characters.updateTransform(renderable.render_id, .{
                .position = .{ pos.x, pos.y, pos.z },
                .rotation = headingToQuat(pos.heading),
                .scale = .{ 1, 1, 1 },
            });
        }
        
        // Sync spell effects
        var effect_iter = world.query(&.{ ecs.Position, ecs.SpellEffect });
        while (effect_iter.next()) |entity| {
            const pos = entity.get(ecs.Position);
            const effect = entity.get(ecs.SpellEffect);
            
            self.effects.updateEffect(effect.effect_id, pos, effect);
        }
    }
    
    pub fn render(self: *WorldRenderer, ctx: *blaze.Context, target: blaze.TextureView) void {
        var encoder = blaze.Encoder.init(self.allocator);
        defer encoder.deinit();
        
        // Update GPU buffers
        self.scene.uploadObjectData(ctx);
        
        // Sky (renders to background)
        self.sky.render(&encoder, &self.camera);
        
        // Terrain (large-scale LOD rendering)
        self.terrain.render(&encoder, &self.camera);
        
        // Main scene (characters, objects)
        self.scene.render(&encoder, &self.camera, target);
        
        // Water (after opaque, before transparent)
        self.water.render(&encoder, &self.camera);
        
        // Effects (particles, spell visuals)
        self.effects.render(&encoder, &self.camera);
        
        ctx.submit(encoder.finish());
    }
};
```

### Terrain Renderer

DAoC's zones need efficient terrain rendering:

```zig
// client/scene/terrain.zig

pub const TerrainRenderer = struct {
    ctx: *blaze.Context,
    
    // Per-zone terrain
    zones: std.AutoHashMap(u16, ZoneTerrain),
    
    // LOD system
    lod_levels: u8 = 5,
    lod_distances: [5]f32 = .{ 50, 150, 400, 1000, 3000 },
    
    pub const ZoneTerrain = struct {
        heightmap: blaze.Texture,        // R16 heightmap
        normalmap: blaze.Texture,        // RGB8 normals
        splatmap: blaze.Texture,         // RGBA8 texture blend weights
        
        terrain_textures: [4]blaze.Texture,  // Grass, dirt, rock, sand
        
        // Clipmap or CDLOD chunks
        chunks: []TerrainChunk,
        
        bounds: BoundingBox,
    };
    
    pub const TerrainChunk = struct {
        x: i32,
        z: i32,
        lod: u8,
        vertex_buffer: blaze.Buffer,
        index_buffer: blaze.Buffer,
        index_count: u32,
    };
    
    pub fn loadZone(self: *TerrainRenderer, zone_id: u16, data: *const ZoneData) !void {
        // Generate terrain meshes at multiple LOD levels
        var chunks = std.ArrayList(TerrainChunk).init(self.allocator);
        
        const chunk_size = 64;  // 64x64 vertices per chunk
        const chunks_x = data.width / chunk_size;
        const chunks_z = data.height / chunk_size;
        
        for (0..chunks_z) |cz| {
            for (0..chunks_x) |cx| {
                // Generate LOD 0 (highest detail)
                const chunk = try self.generateChunk(
                    data,
                    @intCast(cx),
                    @intCast(cz),
                    chunk_size,
                    0,
                );
                try chunks.append(chunk);
            }
        }
        
        // Upload textures
        const heightmap = try self.ctx.createTexture(.{
            .extent = .{ .width = data.width, .height = data.height, .depth = 1 },
            .format = .r16_unorm,
            .usage = .{ .sampled = true, .transfer_dst = true },
        });
        try self.ctx.uploadTexture(heightmap, data.height_data);
        
        try self.zones.put(zone_id, .{
            .heightmap = heightmap,
            .normalmap = try self.generateNormals(data),
            .splatmap = try self.loadSplatmap(zone_id),
            .terrain_textures = try self.loadTerrainTextures(zone_id),
            .chunks = chunks.toOwnedSlice(),
            .bounds = data.bounds,
        });
    }
    
    pub fn render(self: *TerrainRenderer, encoder: *blaze.Encoder, camera: *const forge.Camera) void {
        const active_zone = self.zones.get(self.current_zone_id) orelse return;
        
        encoder.setPipeline(self.terrain_pipeline);
        
        // Bind terrain textures
        encoder.setBindGroup(0, self.createTerrainBindGroup(active_zone));
        
        // Frustum cull and LOD select chunks
        for (active_zone.chunks) |chunk| {
            if (!camera.frustumContains(chunk.bounds)) continue;
            
            const distance = camera.distanceTo(chunk.center);
            const lod = self.selectLod(distance);
            
            if (chunk.lod == lod) {
                encoder.setVertexBuffer(0, chunk.vertex_buffer, 0);
                encoder.setIndexBuffer(chunk.index_buffer, .uint16);
                encoder.drawIndexed(chunk.index_count, 1, 0, 0, 0);
            }
        }
    }
};
```

### Character Renderer

Characters use skeletal animation:

```zig
// client/scene/character_renderer.zig

pub const CharacterRenderer = struct {
    scene: *forge.Scene,
    
    // Mesh library (shared meshes)
    meshes: std.StringHashMap(MeshData),
    
    // Active character instances
    instances: std.AutoHashMap(u32, CharacterInstance),
    
    // Animation data
    skeletons: std.StringHashMap(Skeleton),
    animations: std.StringHashMap(AnimationClip),
    
    pub const CharacterInstance = struct {
        mesh_id: u32,
        skeleton: *Skeleton,
        
        // Current animation state
        current_anim: ?*AnimationClip,
        anim_time: f32,
        blend_anim: ?*AnimationClip,
        blend_time: f32,
        blend_factor: f32,
        
        // Computed bone matrices (uploaded to GPU)
        bone_matrices: []Mat4,
        bone_buffer: blaze.Buffer,
        
        // FORGE render handle
        forge_object: forge.ObjectId,
        
        // Equipment attachments
        weapon_attachment: ?AttachmentPoint,
        shield_attachment: ?AttachmentPoint,
        helmet_attachment: ?AttachmentPoint,
    };
    
    pub fn spawnCharacter(
        self: *CharacterRenderer,
        render_id: u32,
        model_name: []const u8,
        position: Vec3,
    ) !void {
        const mesh = self.meshes.get(model_name) orelse 
            try self.loadMesh(model_name);
        const skeleton = self.skeletons.get(model_name) orelse
            try self.loadSkeleton(model_name);
        
        // Allocate bone matrices
        const bone_matrices = try self.allocator.alloc(Mat4, skeleton.bone_count);
        @memset(bone_matrices, Mat4.identity);
        
        // Create GPU buffer for bone matrices
        const bone_buffer = try self.scene.ctx.createBuffer(.{
            .size = skeleton.bone_count * @sizeOf(Mat4),
            .usage = .{ .uniform = true, .transfer_dst = true },
            .memory = .device_local,
        });
        
        // Add to FORGE scene
        const forge_object = try self.scene.addObject(.{
            .mesh = mesh.forge_mesh,
            .material = mesh.material,
            .transform = Mat4.translation(position),
            .skeleton_buffer = bone_buffer,
        });
        
        try self.instances.put(render_id, .{
            .mesh_id = mesh.id,
            .skeleton = skeleton,
            .current_anim = null,
            .anim_time = 0,
            .blend_anim = null,
            .blend_time = 0,
            .blend_factor = 0,
            .bone_matrices = bone_matrices,
            .bone_buffer = bone_buffer,
            .forge_object = forge_object,
            .weapon_attachment = null,
            .shield_attachment = null,
            .helmet_attachment = null,
        });
    }
    
    pub fn updateAnimation(self: *CharacterRenderer, render_id: u32, anim_state: *const ecs.Animation) void {
        const instance = self.instances.getPtr(render_id) orelse return;
        
        // Determine animation clip from state
        const clip = switch (anim_state.state) {
            .idle => self.animations.get("idle"),
            .walk => self.animations.get("walk"),
            .run => self.animations.get("run"),
            .combat_idle => self.animations.get("combat_idle"),
            .attack => self.animations.get(anim_state.attack_anim orelse "attack_01"),
            .cast => self.animations.get("cast"),
            .death => self.animations.get("death"),
            else => null,
        };
        
        if (clip) |c| {
            if (instance.current_anim != c) {
                // Start blend to new animation
                instance.blend_anim = instance.current_anim;
                instance.blend_time = instance.anim_time;
                instance.blend_factor = 0;
                instance.current_anim = c;
                instance.anim_time = 0;
            }
        }
    }
    
    pub fn tick(self: *CharacterRenderer, dt: f32) void {
        var iter = self.instances.iterator();
        while (iter.next()) |entry| {
            var instance = entry.value_ptr;
            
            // Advance animation time
            if (instance.current_anim) |anim| {
                instance.anim_time += dt;
                if (instance.anim_time > anim.duration) {
                    if (anim.looping) {
                        instance.anim_time = @mod(instance.anim_time, anim.duration);
                    } else {
                        instance.anim_time = anim.duration;
                    }
                }
                
                // Update blend factor
                if (instance.blend_anim != null) {
                    instance.blend_factor += dt * 5.0;  // Blend over 0.2 seconds
                    if (instance.blend_factor >= 1.0) {
                        instance.blend_anim = null;
                        instance.blend_factor = 1.0;
                    }
                }
                
                // Compute bone matrices
                self.computeBoneMatrices(instance);
                
                // Upload to GPU
                self.scene.ctx.uploadBuffer(
                    instance.bone_buffer,
                    std.mem.sliceAsBytes(instance.bone_matrices),
                );
            }
        }
    }
    
    fn computeBoneMatrices(self: *CharacterRenderer, instance: *CharacterInstance) void {
        const skeleton = instance.skeleton;
        const anim = instance.current_anim orelse return;
        
        for (0..skeleton.bone_count) |i| {
            const bone = &skeleton.bones[i];
            
            // Sample current animation
            var local_transform = anim.sample(i, instance.anim_time);
            
            // Blend with previous animation
            if (instance.blend_anim) |blend| {
                const blend_transform = blend.sample(i, instance.blend_time);
                local_transform = Mat4.lerp(blend_transform, local_transform, instance.blend_factor);
            }
            
            // Compute world transform (parent chain)
            const world_transform = if (bone.parent_idx) |parent|
                instance.bone_matrices[parent].mul(local_transform)
            else
                local_transform;
            
            // Final matrix = world × inverse_bind_pose
            instance.bone_matrices[i] = world_transform.mul(bone.inverse_bind_pose);
        }
    }
};
```

### Effect Renderer

Spell effects and particles:

```zig
// client/scene/effects.zig

pub const EffectRenderer = struct {
    ctx: *blaze.Context,
    
    // Particle systems
    particle_systems: std.ArrayList(ParticleSystem),
    
    // Effect templates
    effect_templates: std.StringHashMap(EffectTemplate),
    
    // GPU buffers
    particle_buffer: blaze.Buffer,      // Instance data
    max_particles: u32 = 100_000,
    
    pub const ParticleSystem = struct {
        template: *EffectTemplate,
        position: Vec3,
        rotation: Quat,
        time: f32,
        duration: f32,
        particles: []Particle,
        active_count: u32,
        
        pub const Particle = struct {
            position: Vec3,
            velocity: Vec3,
            color: [4]f32,
            size: f32,
            age: f32,
            max_age: f32,
        };
    };
    
    pub const EffectTemplate = struct {
        name: []const u8,
        texture: blaze.Texture,
        
        // Emission
        emit_rate: f32,           // Particles per second
        emit_shape: EmitShape,
        
        // Particle properties
        initial_velocity: Vec3,
        velocity_variance: Vec3,
        initial_size: f32,
        size_over_life: [4]f32,   // Curve
        initial_color: [4]f32,
        color_over_life: [4][4]f32,  // Gradient
        lifetime: f32,
        lifetime_variance: f32,
        gravity: f32,
        
        // Rendering
        blend_mode: BlendMode,
        sort_mode: SortMode,
    };
    
    /// Spawn a spell effect
    pub fn spawnEffect(
        self: *EffectRenderer,
        effect_name: []const u8,
        position: Vec3,
        target: ?Vec3,
        duration: f32,
    ) !u32 {
        const template = self.effect_templates.get(effect_name) orelse return error.UnknownEffect;
        
        const system = ParticleSystem{
            .template = template,
            .position = position,
            .rotation = if (target) |t| quatLookAt(position, t) else Quat.identity,
            .time = 0,
            .duration = duration,
            .particles = try self.allocator.alloc(ParticleSystem.Particle, 1000),
            .active_count = 0,
        };
        
        try self.particle_systems.append(system);
        return @intCast(self.particle_systems.items.len - 1);
    }
    
    pub fn tick(self: *EffectRenderer, dt: f32) void {
        // Update all particle systems
        var i: usize = 0;
        while (i < self.particle_systems.items.len) {
            var system = &self.particle_systems.items[i];
            
            system.time += dt;
            
            // Check if expired
            if (system.time > system.duration) {
                // Remove system
                _ = self.particle_systems.swapRemove(i);
                continue;
            }
            
            // Emit new particles
            self.emitParticles(system, dt);
            
            // Update existing particles
            self.updateParticles(system, dt);
            
            i += 1;
        }
    }
    
    fn emitParticles(self: *EffectRenderer, system: *ParticleSystem, dt: f32) void {
        const template = system.template;
        const emit_count = @as(u32, @intFromFloat(template.emit_rate * dt));
        
        for (0..emit_count) |_| {
            if (system.active_count >= system.particles.len) break;
            
            // Initialize new particle
            var p = &system.particles[system.active_count];
            p.position = system.position;
            p.position += randomInShape(template.emit_shape);
            p.velocity = template.initial_velocity;
            p.velocity += randomVec3() * template.velocity_variance;
            p.color = template.initial_color;
            p.size = template.initial_size;
            p.age = 0;
            p.max_age = template.lifetime + (random.float(f32) - 0.5) * template.lifetime_variance;
            
            system.active_count += 1;
        }
    }
    
    fn updateParticles(self: *EffectRenderer, system: *ParticleSystem, dt: f32) void {
        const template = system.template;
        
        var i: u32 = 0;
        while (i < system.active_count) {
            var p = &system.particles[i];
            
            p.age += dt;
            
            // Check if dead
            if (p.age >= p.max_age) {
                // Swap with last active particle
                system.particles[i] = system.particles[system.active_count - 1];
                system.active_count -= 1;
                continue;
            }
            
            // Update physics
            p.velocity.y -= template.gravity * dt;
            p.position += p.velocity * dt;
            
            // Update visual properties over lifetime
            const t = p.age / p.max_age;
            p.size = sampleCurve(template.size_over_life, t) * template.initial_size;
            p.color = sampleGradient(template.color_over_life, t);
            
            i += 1;
        }
    }
    
    pub fn render(self: *EffectRenderer, encoder: *blaze.Encoder, camera: *const forge.Camera) void {
        // Batch all particles into GPU buffer
        var particle_data = std.ArrayList(GpuParticle).init(self.allocator);
        defer particle_data.deinit();
        
        for (self.particle_systems.items) |system| {
            for (system.particles[0..system.active_count]) |p| {
                particle_data.append(.{
                    .position = p.position,
                    .color = p.color,
                    .size = p.size,
                    .texture_id = system.template.texture_id,
                }) catch continue;
            }
        }
        
        if (particle_data.items.len == 0) return;
        
        // Upload to GPU
        self.ctx.uploadBuffer(self.particle_buffer, std.mem.sliceAsBytes(particle_data.items));
        
        // Draw instanced quads
        encoder.setPipeline(self.particle_pipeline);
        encoder.setBindGroup(0, self.particle_bind_group);
        encoder.draw(4, @intCast(particle_data.items.len));
    }
};
```

---

## Part 5: FLUX - UI Framework

### HUD Layout

```zig
// client/ui/hud.zig

const std = @import("std");
const flux = @import("flux");
const game = @import("../game.zig");

pub const HudState = struct {
    // Player state (from ECS)
    health: i32,
    max_health: i32,
    mana: i32,
    max_mana: i32,
    endurance: i32,
    max_endurance: i32,
    
    // Target
    target: ?TargetInfo,
    
    // Chat
    chat_log: std.ArrayList(ChatMessage),
    chat_input: [256]u8,
    chat_input_len: usize,
    chat_focused: bool,
    
    // Hotbars
    hotbar_1: [10]?HotbarSlot,
    hotbar_2: [10]?HotbarSlot,
    
    // Windows
    inventory_open: bool,
    character_open: bool,
    spellbook_open: bool,
    map_open: bool,
    
    pub const TargetInfo = struct {
        name: []const u8,
        health_pct: f32,
        level: u8,
        con_color: ConColor,
    };
    
    pub const HotbarSlot = struct {
        icon: flux.TextureId,
        name: []const u8,
        cooldown: f32,
        max_cooldown: f32,
        usable: bool,
    };
};

/// Main HUD view
pub fn hudView(state: *HudState, screen_size: flux.Size) flux.Element {
    return flux.stack(.{ .width = screen_size.width, .height = screen_size.height }, .{
        // Bottom center: Hotbars
        flux.positioned(.{ .bottom = 10, .center_x = true }, .{
            hotbars(state),
        }),
        
        // Top left: Player health/mana/endurance
        flux.positioned(.{ .top = 10, .left = 10 }, .{
            playerBars(state),
        }),
        
        // Top center: Target info
        if (state.target) |target|
            flux.positioned(.{ .top = 10, .center_x = true }, .{
                targetFrame(target),
            })
        else
            flux.empty(),
        
        // Bottom left: Chat
        flux.positioned(.{ .bottom = 80, .left = 10 }, .{
            chatBox(state),
        }),
        
        // Right side: Minimap
        flux.positioned(.{ .top = 10, .right = 10 }, .{
            minimap(state),
        }),
        
        // Floating windows
        if (state.inventory_open)
            inventoryWindow(state)
        else
            flux.empty(),
        
        if (state.character_open)
            characterWindow(state)
        else
            flux.empty(),
        
        if (state.spellbook_open)
            spellbookWindow(state)
        else
            flux.empty(),
    });
}

fn playerBars(state: *HudState) flux.Element {
    return flux.column(.{ .gap = 2 }, .{
        // Health bar
        resourceBar(
            state.health,
            state.max_health,
            flux.Color.fromRgb(0.8, 0.2, 0.2),  // Red
            "HP",
        ),
        
        // Mana bar
        resourceBar(
            state.mana,
            state.max_mana,
            flux.Color.fromRgb(0.2, 0.2, 0.8),  // Blue
            "MP",
        ),
        
        // Endurance bar
        resourceBar(
            state.endurance,
            state.max_endurance,
            flux.Color.fromRgb(0.8, 0.8, 0.2),  // Yellow
            "End",
        ),
    });
}

fn resourceBar(current: i32, max: i32, color: flux.Color, label: []const u8) flux.Element {
    const pct = @as(f32, @floatFromInt(current)) / @as(f32, @floatFromInt(max));
    
    return flux.container(.{
        .width = 200,
        .height = 20,
        .style = .{ .background = flux.Color.fromRgba(0, 0, 0, 0.5), .border_radius = 3 },
    }, .{
        // Fill bar
        flux.container(.{
            .width = @as(f32, 200) * pct,
            .height = 20,
            .style = .{ .background = color, .border_radius = 3 },
        }, .{}),
        
        // Text overlay
        flux.positioned(.{ .center_x = true, .center_y = true }, .{
            flux.text(std.fmt.allocPrint(
                state.allocator,
                "{s}: {d}/{d}",
                .{ label, current, max },
            ) catch "", .{
                .color = flux.Color.white,
                .size = 12,
                .shadow = true,
            }),
        }),
    });
}

fn hotbars(state: *HudState) flux.Element {
    return flux.column(.{ .gap = 4 }, .{
        hotbarRow(state.hotbar_1, 0),
        hotbarRow(state.hotbar_2, 1),
    });
}

fn hotbarRow(slots: [10]?HotbarSlot, row: usize) flux.Element {
    var elements: [10]flux.Element = undefined;
    
    for (slots, 0..) |slot_opt, i| {
        elements[i] = hotbarSlot(slot_opt, row, i);
    }
    
    return flux.row(.{ .gap = 2 }, &elements);
}

fn hotbarSlot(slot: ?HotbarSlot, row: usize, index: usize) flux.Element {
    const size: f32 = 40;
    
    return flux.container(.{
        .width = size,
        .height = size,
        .style = .{
            .background = flux.Color.fromRgba(0.1, 0.1, 0.1, 0.8),
            .border = .{ .width = 1, .color = flux.Color.fromRgb(0.4, 0.4, 0.4) },
            .border_radius = 4,
        },
    }, .{
        if (slot) |s| slot_content: {
            break :slot_content flux.stack(.{}, .{
                // Icon
                flux.image(s.icon, .{ .width = size - 4, .height = size - 4 }),
                
                // Cooldown overlay
                if (s.cooldown > 0)
                    cooldownOverlay(s.cooldown, s.max_cooldown, size)
                else
                    flux.empty(),
                
                // Keybind hint
                flux.positioned(.{ .bottom = 2, .right = 2 }, .{
                    flux.text(keybindText(row, index), .{
                        .size = 10,
                        .color = flux.Color.white,
                        .shadow = true,
                    }),
                }),
                
                // Unusable darkening
                if (!s.usable)
                    flux.container(.{
                        .width = size,
                        .height = size,
                        .style = .{ .background = flux.Color.fromRgba(0, 0, 0, 0.5) },
                    }, .{})
                else
                    flux.empty(),
            });
        } else flux.empty(),
    });
}

fn cooldownOverlay(cooldown: f32, max_cooldown: f32, size: f32) flux.Element {
    const pct = cooldown / max_cooldown;
    
    // Pie-chart style cooldown
    return flux.custom(.{
        .width = size,
        .height = size,
    }, struct {
        fn paint(rect: flux.Rect, draw_list: *flux.DrawList) void {
            draw_list.addPieOverlay(rect, pct, flux.Color.fromRgba(0, 0, 0, 0.6));
            
            // Cooldown text
            if (cooldown >= 1) {
                draw_list.addTextCentered(
                    rect,
                    std.fmt.bufPrint(&buf, "{d:.0}", .{cooldown}) catch "?",
                    .{ .size = 14, .color = flux.Color.white },
                );
            }
        }
    }.paint);
}

fn targetFrame(target: HudState.TargetInfo) flux.Element {
    return flux.container(.{
        .width = 250,
        .style = .{
            .background = flux.Color.fromRgba(0.1, 0.1, 0.1, 0.8),
            .border = .{ .width = 2, .color = target.con_color.toFluxColor() },
            .border_radius = 4,
            .padding = .{ .all = 8 },
        },
    }, .{
        flux.column(.{ .gap = 4 }, .{
            // Name and level
            flux.row(.{ .justify = .space_between }, .{
                flux.text(target.name, .{
                    .size = 14,
                    .color = flux.Color.white,
                    .weight = .bold,
                }),
                flux.text(std.fmt.allocPrint(
                    state.allocator,
                    "Lv {d}",
                    .{target.level},
                ) catch "", .{
                    .size = 12,
                    .color = target.con_color.toFluxColor(),
                }),
            }),
            
            // Health bar
            flux.container(.{
                .height = 12,
                .style = .{ .background = flux.Color.fromRgb(0.2, 0.0, 0.0) },
            }, .{
                flux.container(.{
                    .width = 234 * target.health_pct,
                    .height = 12,
                    .style = .{ .background = flux.Color.fromRgb(0.8, 0.0, 0.0) },
                }, .{}),
            }),
        }),
    });
}

fn chatBox(state: *HudState) flux.Element {
    return flux.container(.{
        .width = 400,
        .height = 200,
        .style = .{
            .background = flux.Color.fromRgba(0, 0, 0, 0.5),
            .border_radius = 4,
        },
    }, .{
        flux.column(.{ .flex = 1 }, .{
            // Message log (scrollable)
            flux.scroll(.{ .flex = 1, .scroll_y = true }, .{
                flux.column(.{ .gap = 2 }, blk: {
                    var elements: [100]flux.Element = undefined;
                    const count = @min(state.chat_log.items.len, 100);
                    for (state.chat_log.items[state.chat_log.items.len - count..], 0..) |msg, i| {
                        elements[i] = chatMessage(msg);
                    }
                    break :blk elements[0..count];
                }),
            }),
            
            // Input field
            flux.container(.{
                .height = 24,
                .style = .{
                    .background = flux.Color.fromRgba(0.1, 0.1, 0.1, 0.8),
                    .border = .{
                        .width = 1,
                        .color = if (state.chat_focused)
                            flux.Color.fromRgb(0.5, 0.5, 1.0)
                        else
                            flux.Color.fromRgb(0.3, 0.3, 0.3),
                    },
                },
            }, .{
                flux.input(state.chat_input[0..state.chat_input_len], .{
                    .placeholder = "Press Enter to chat...",
                    .on_submit = submitChat,
                    .on_focus = struct {
                        fn focus(s: *HudState) void { s.chat_focused = true; }
                    }.focus,
                    .on_blur = struct {
                        fn blur(s: *HudState) void { s.chat_focused = false; }
                    }.blur,
                }),
            }),
        }),
    });
}

fn chatMessage(msg: ChatMessage) flux.Element {
    const color = switch (msg.channel) {
        .say => flux.Color.white,
        .group => flux.Color.fromRgb(0.5, 0.5, 1.0),
        .guild => flux.Color.fromRgb(0.2, 1.0, 0.2),
        .broadcast => flux.Color.fromRgb(1.0, 0.5, 0.0),
        .system => flux.Color.fromRgb(1.0, 1.0, 0.5),
    };
    
    return flux.text(
        std.fmt.allocPrint(state.allocator, "[{s}] {s}", .{ msg.sender, msg.text }) catch "",
        .{ .size = 12, .color = color },
    );
}
```

### Inventory Window

```zig
// client/ui/inventory.zig

pub fn inventoryWindow(state: *HudState) flux.Element {
    return flux.window(.{
        .title = "Inventory",
        .x = state.inventory_pos.x,
        .y = state.inventory_pos.y,
        .width = 300,
        .height = 400,
        .draggable = true,
        .closable = true,
        .on_close = struct {
            fn close(s: *HudState) void { s.inventory_open = false; }
        }.close,
    }, .{
        flux.column(.{ .gap = 8, .padding = .{ .all = 8 } }, .{
            // Currency
            flux.row(.{ .gap = 16 }, .{
                currencyDisplay("Gold", state.gold, .gold),
                currencyDisplay("Silver", state.silver, .silver),
                currencyDisplay("Copper", state.copper, .copper),
            }),
            
            // Bag slots (8x5 grid = 40 slots)
            inventoryGrid(state.inventory_slots, 8, 5),
        }),
    });
}

fn inventoryGrid(slots: []?ItemSlot, cols: usize, rows: usize) flux.Element {
    var row_elements: [5]flux.Element = undefined;
    
    for (0..rows) |row| {
        var col_elements: [8]flux.Element = undefined;
        
        for (0..cols) |col| {
            const idx = row * cols + col;
            col_elements[col] = itemSlot(if (idx < slots.len) slots[idx] else null, idx);
        }
        
        row_elements[row] = flux.row(.{ .gap = 2 }, &col_elements);
    }
    
    return flux.column(.{ .gap = 2 }, &row_elements);
}

fn itemSlot(item: ?ItemSlot, slot_idx: usize) flux.Element {
    const size: f32 = 32;
    
    return flux.container(.{
        .width = size,
        .height = size,
        .style = .{
            .background = flux.Color.fromRgba(0.15, 0.15, 0.15, 1.0),
            .border = .{ .width = 1, .color = flux.Color.fromRgb(0.3, 0.3, 0.3) },
        },
        .on_click = struct {
            fn click(s: *HudState) void {
                s.handleInventoryClick(slot_idx);
            }
        }.click,
        .on_right_click = struct {
            fn rightClick(s: *HudState) void {
                s.handleInventoryRightClick(slot_idx);
            }
        }.rightClick,
        .on_hover = struct {
            fn hover(s: *HudState) void {
                if (item) |i| {
                    s.showTooltip(i.getTooltip());
                }
            }
        }.hover,
    }, .{
        if (item) |i| blk: {
            break :blk flux.stack(.{}, .{
                // Item icon
                flux.image(i.icon, .{ .width = size - 2, .height = size - 2 }),
                
                // Stack count (if stackable)
                if (i.count > 1)
                    flux.positioned(.{ .bottom = 1, .right = 1 }, .{
                        flux.text(
                            std.fmt.allocPrint(state.allocator, "{d}", .{i.count}) catch "",
                            .{ .size = 10, .color = flux.Color.white, .shadow = true },
                        ),
                    })
                else
                    flux.empty(),
                
                // Quality border color
                flux.container(.{
                    .width = size,
                    .height = size,
                    .style = .{
                        .border = .{ .width = 1, .color = i.quality.borderColor() },
                    },
                }, .{}),
            });
        } else flux.empty(),
    });
}
```

### Spellbook Window

```zig
// client/ui/spellbook.zig

pub fn spellbookWindow(state: *HudState) flux.Element {
    return flux.window(.{
        .title = "Spellbook",
        .width = 350,
        .height = 450,
        .draggable = true,
        .closable = true,
    }, .{
        flux.column(.{ .gap = 8, .padding = .{ .all = 8 } }, .{
            // Spec line tabs
            flux.row(.{ .gap = 4 }, blk: {
                var tabs: [8]flux.Element = undefined;
                for (state.spec_lines, 0..) |spec, i| {
                    tabs[i] = specLineTab(spec, i == state.selected_spec_line);
                }
                break :blk tabs[0..state.spec_lines.len];
            }),
            
            // Spell list for selected spec line
            flux.scroll(.{ .flex = 1, .scroll_y = true }, .{
                flux.column(.{ .gap = 4 }, blk: {
                    const spec = state.spec_lines[state.selected_spec_line];
                    var spells: [50]flux.Element = undefined;
                    var count: usize = 0;
                    
                    for (spec.spells) |spell| {
                        if (spell.level_required <= state.spec_levels[state.selected_spec_line]) {
                            spells[count] = spellEntry(spell, state);
                            count += 1;
                        }
                    }
                    
                    break :blk spells[0..count];
                }),
            }),
        }),
    });
}

fn spellEntry(spell: *const SpellData, state: *HudState) flux.Element {
    return flux.container(.{
        .height = 48,
        .style = .{
            .background = flux.Color.fromRgba(0.1, 0.1, 0.1, 0.8),
            .border_radius = 4,
            .padding = .{ .all = 4 },
        },
        .draggable = true,  // Can drag to hotbar
        .drag_data = .{ .spell_id = spell.id },
    }, .{
        flux.row(.{ .gap = 8 }, .{
            // Icon
            flux.image(spell.icon, .{ .width = 40, .height = 40 }),
            
            // Info
            flux.column(.{ .gap = 2, .flex = 1 }, .{
                flux.text(spell.name, .{
                    .size = 14,
                    .color = flux.Color.white,
                    .weight = .bold,
                }),
                flux.text(std.fmt.allocPrint(
                    state.allocator,
                    "Level {d} | {d} Power | {d}s cast",
                    .{ spell.level_required, spell.power_cost, spell.cast_time },
                ) catch "", .{
                    .size = 11,
                    .color = flux.Color.fromRgb(0.7, 0.7, 0.7),
                }),
            }),
        }),
    });
}
```

---

## Part 6: EMBER - Game Framework

The reusable parts extracted into a game framework:

### Framework Core

```zig
// ember/app.zig

const std = @import("std");
const blaze = @import("blaze");
const forge = @import("forge");
const flux = @import("flux");

/// EMBER Game Application
pub fn GameApp(comptime GameState: type, comptime Config: type) type {
    return struct {
        const Self = @This();
        
        allocator: std.mem.Allocator,
        
        // Core systems
        blaze_ctx: blaze.Context,
        forge_scene: forge.Scene,
        flux_app: flux.App(GameState, Config.ui_view),
        
        // Game state
        state: *GameState,
        
        // Timing
        last_frame_time: i64,
        accumulator: f64,
        fixed_dt: f64,
        
        // Input
        input: InputState,
        
        pub fn init(allocator: std.mem.Allocator, config: Config) !*Self {
            var self = try allocator.create(Self);
            
            // Initialize BLAZE
            self.blaze_ctx = try blaze.Context.init(allocator, .{
                .app_name = Config.app_name,
                .validation = std.builtin.mode == .Debug,
            });
            
            // Initialize FORGE scene
            self.forge_scene = try forge.Scene.init(&self.blaze_ctx, Config.scene_config);
            
            // Initialize game state
            self.state = try GameState.init(allocator, &self.forge_scene);
            
            // Initialize FLUX UI
            self.flux_app = try flux.App(GameState, Config.ui_view).init(
                allocator,
                self.state,
                .{
                    .title = Config.window_title,
                    .width = Config.window_width,
                    .height = Config.window_height,
                    .blaze_context = &self.blaze_ctx,
                },
            );
            
            self.fixed_dt = 1.0 / @as(f64, Config.tick_rate);
            self.accumulator = 0;
            self.last_frame_time = std.time.nanoTimestamp();
            
            return self;
        }
        
        pub fn run(self: *Self) !void {
            while (!self.flux_app.shouldClose()) {
                const now = std.time.nanoTimestamp();
                const frame_time = @as(f64, @floatFromInt(now - self.last_frame_time)) / 1_000_000_000.0;
                self.last_frame_time = now;
                
                self.accumulator += frame_time;
                
                // Fixed timestep updates
                while (self.accumulator >= self.fixed_dt) {
                    self.state.fixedUpdate(@floatCast(self.fixed_dt));
                    self.accumulator -= self.fixed_dt;
                }
                
                // Variable timestep update
                self.state.update(@floatCast(frame_time));
                
                // Render
                try self.render(@floatCast(self.accumulator / self.fixed_dt));
            }
        }
        
        fn render(self: *Self, alpha: f32) !void {
            // Sync ECS to FORGE
            self.state.syncToRenderer(&self.forge_scene, alpha);
            
            // Render 3D scene
            const target = try self.blaze_ctx.acquireSwapchainImage();
            self.forge_scene.render(target);
            
            // Render UI
            try self.flux_app.render();
            
            // Present
            try self.blaze_ctx.present();
        }
    };
}
```

### Asset Manager

```zig
// ember/assets.zig

pub const AssetManager = struct {
    allocator: std.mem.Allocator,
    ctx: *blaze.Context,
    
    // Asset caches
    textures: std.StringHashMap(blaze.Texture),
    meshes: std.StringHashMap(forge.Mesh),
    materials: std.StringHashMap(forge.Material),
    sounds: std.StringHashMap(AudioBuffer),
    animations: std.StringHashMap(AnimationClip),
    
    // Asset loaders (pluggable)
    texture_loader: *const fn ([]const u8) anyerror!TextureData,
    mesh_loader: *const fn ([]const u8) anyerror!MeshData,
    
    // Loading queue (async)
    load_queue: std.ArrayList(LoadRequest),
    load_thread: ?std.Thread,
    
    pub fn loadTexture(self: *AssetManager, path: []const u8) !blaze.Texture {
        if (self.textures.get(path)) |tex| return tex;
        
        const data = try self.texture_loader(path);
        defer data.deinit();
        
        const texture = try self.ctx.createTexture(.{
            .extent = .{ .width = data.width, .height = data.height, .depth = 1 },
            .format = data.format,
            .usage = .{ .sampled = true, .transfer_dst = true },
            .mip_levels = data.mip_count,
        });
        
        try self.ctx.uploadTexture(texture, data.pixels);
        try self.textures.put(path, texture);
        
        return texture;
    }
    
    pub fn loadMesh(self: *AssetManager, path: []const u8) !forge.Mesh {
        if (self.meshes.get(path)) |mesh| return mesh;
        
        const data = try self.mesh_loader(path);
        defer data.deinit();
        
        const mesh = try self.forge_scene.uploadMesh(data);
        try self.meshes.put(path, mesh);
        
        return mesh;
    }
    
    /// Queue async load
    pub fn loadAsync(self: *AssetManager, path: []const u8, callback: LoadCallback) void {
        self.load_queue.append(.{
            .path = path,
            .callback = callback,
        }) catch return;
        
        // Start load thread if not running
        if (self.load_thread == null) {
            self.load_thread = std.Thread.spawn(.{}, loadThreadFn, .{self}) catch null;
        }
    }
    
    fn loadThreadFn(self: *AssetManager) void {
        while (self.load_queue.popOrNull()) |request| {
            // Determine asset type from extension
            const ext = std.fs.path.extension(request.path);
            
            const result = if (std.mem.eql(u8, ext, ".dds") or std.mem.eql(u8, ext, ".png"))
                self.loadTexture(request.path)
            else if (std.mem.eql(u8, ext, ".nif") or std.mem.eql(u8, ext, ".gltf"))
                self.loadMesh(request.path)
            else
                error.UnknownAssetType;
            
            request.callback(result);
        }
        
        self.load_thread = null;
    }
};
```

### Scene Graph

```zig
// ember/scene.zig

pub const SceneGraph = struct {
    allocator: std.mem.Allocator,
    
    // Nodes
    nodes: std.ArrayList(SceneNode),
    root: NodeId,
    
    // Spatial index for culling
    octree: Octree,
    
    pub const NodeId = u32;
    
    pub const SceneNode = struct {
        id: NodeId,
        parent: ?NodeId,
        children: std.ArrayList(NodeId),
        
        // Transform
        local_transform: Transform,
        world_transform: Transform,  // Cached
        transform_dirty: bool,
        
        // Render data
        mesh: ?forge.Mesh,
        material: ?forge.Material,
        bounds: ?BoundingBox,
        
        // Components (entity link)
        entity: ?ecs.Entity,
    };
    
    pub fn createNode(self: *SceneGraph, parent: ?NodeId) !NodeId {
        const id: NodeId = @intCast(self.nodes.items.len);
        
        try self.nodes.append(.{
            .id = id,
            .parent = parent,
            .children = std.ArrayList(NodeId).init(self.allocator),
            .local_transform = Transform.identity,
            .world_transform = Transform.identity,
            .transform_dirty = true,
            .mesh = null,
            .material = null,
            .bounds = null,
            .entity = null,
        });
        
        if (parent) |p| {
            try self.nodes.items[p].children.append(id);
        }
        
        return id;
    }
    
    pub fn setTransform(self: *SceneGraph, node: NodeId, transform: Transform) void {
        self.nodes.items[node].local_transform = transform;
        self.markDirty(node);
    }
    
    fn markDirty(self: *SceneGraph, node: NodeId) void {
        self.nodes.items[node].transform_dirty = true;
        
        for (self.nodes.items[node].children.items) |child| {
            self.markDirty(child);
        }
    }
    
    pub fn updateWorldTransforms(self: *SceneGraph) void {
        self.updateNodeTransform(self.root, Transform.identity);
    }
    
    fn updateNodeTransform(self: *SceneGraph, node: NodeId, parent_world: Transform) void {
        var n = &self.nodes.items[node];
        
        if (n.transform_dirty) {
            n.world_transform = parent_world.combine(n.local_transform);
            n.transform_dirty = false;
        }
        
        for (n.children.items) |child| {
            self.updateNodeTransform(child, n.world_transform);
        }
    }
    
    /// Gather visible nodes for rendering
    pub fn gatherVisible(self: *SceneGraph, frustum: Frustum) []const SceneNode {
        var visible = std.ArrayList(*const SceneNode).init(self.allocator);
        
        self.octree.query(frustum, &visible);
        
        return visible.toOwnedSlice();
    }
};
```

---

## Part 7: Server Architecture (Unchanged from Original)

The server remains pure Zig with no graphics dependencies:

```zig
// server/main.zig

const std = @import("std");
const xev = @import("xev");
const ecs = @import("../common/ecs/world.zig");
const db = @import("db/database.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Initialize database
    var database = try db.Database.init("daoc.db");
    defer database.deinit();
    
    // Initialize game world
    var world = try ecs.World.init(allocator);
    defer world.deinit();
    
    // Load zone data
    try loadZones(&world, &database);
    
    // Initialize network
    var server = try GameServer.init(allocator, 10300);
    defer server.deinit();
    
    server.world = &world;
    server.database = &database;
    
    std.log.info("DAoC server starting on port 10300...", .{});
    
    try server.run();
}

pub const GameServer = struct {
    loop: xev.Loop,
    listener: xev.TCP,
    clients: std.AutoHashMap(u32, *Client),
    world: *ecs.World,
    database: *db.Database,
    
    // Server tick rate: 20 Hz (50ms)
    const TICK_RATE = 20;
    const TICK_NS = 1_000_000_000 / TICK_RATE;
    
    pub fn run(self: *GameServer) !void {
        var last_tick = std.time.nanoTimestamp();
        
        while (true) {
            // Process network events
            try self.loop.run(.{ .timeout_ns = TICK_NS });
            
            const now = std.time.nanoTimestamp();
            const elapsed = now - last_tick;
            
            if (elapsed >= TICK_NS) {
                const dt = @as(f32, @floatFromInt(elapsed)) / 1_000_000_000.0;
                self.tick(dt);
                last_tick = now;
            }
        }
    }
    
    fn tick(self: *GameServer, dt: f32) void {
        // Game systems (server-authoritative)
        systems.movement(self.world, dt);
        systems.combat(self.world, dt);
        systems.ai(self.world, dt);
        systems.regen(self.world, dt);
        systems.buffs(self.world, dt);
        systems.spawn(self.world, dt);
        
        // Broadcast state to clients
        self.broadcastWorldState();
        
        // Periodic database saves
        if (self.tick_count % (TICK_RATE * 60) == 0) {  // Every minute
            self.saveAllCharacters();
        }
        
        self.tick_count += 1;
    }
    
    fn broadcastWorldState(self: *GameServer) void {
        // For each client, send relevant entity updates
        var client_iter = self.clients.iterator();
        while (client_iter.next()) |entry| {
            const client = entry.value_ptr.*;
            
            if (client.player_entity) |player| {
                const player_pos = player.get(ecs.Position);
                
                // Get nearby entities
                const zone = self.world.getZone(player_pos.zone_id);
                const nearby = zone.getEntitiesInRange(player_pos, 5000);  // ~500 unit range
                
                // Build and send update packet
                var packet = PlayerAreaUpdatePacket.init();
                for (nearby) |entity| {
                    packet.addEntity(entity);
                }
                client.send(packet.finalize());
            }
        }
    }
};
```

---

## Part 8: Build Configuration

```zig
// build.zig

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    
    // Dependencies
    const blaze = b.dependency("blaze", .{ .target = target, .optimize = optimize });
    const forge = b.dependency("forge", .{ .target = target, .optimize = optimize });
    const flux = b.dependency("flux", .{ .target = target, .optimize = optimize });
    const xev = b.dependency("libxev", .{ .target = target, .optimize = optimize });
    const sqlite = b.dependency("sqlite", .{ .target = target, .optimize = optimize });
    
    // Common library (shared between client/server)
    const common = b.addStaticLibrary(.{
        .name = "daoc-common",
        .root_source_file = b.path("src/common/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    // Server executable
    const server = b.addExecutable(.{
        .name = "daoc-server",
        .root_source_file = b.path("src/server/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    server.addModule("common", common.module);
    server.addModule("xev", xev.module("xev"));
    server.addModule("sqlite", sqlite.module("sqlite"));
    
    if (target.result.os.tag == .linux) {
        server.linkLibC();
    }
    
    // Client executable
    const client = b.addExecutable(.{
        .name = "daoc-client",
        .root_source_file = b.path("src/client/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    client.addModule("common", common.module);
    client.addModule("blaze", blaze.module("blaze"));
    client.addModule("forge", forge.module("forge"));
    client.addModule("flux", flux.module("flux"));
    
    // Link Vulkan
    client.linkSystemLibrary("vulkan");
    
    // Install
    b.installArtifact(server);
    b.installArtifact(client);
    
    // Run steps
    const run_server = b.addRunArtifact(server);
    const run_client = b.addRunArtifact(client);
    
    b.step("server", "Run the server").dependOn(&run_server.step);
    b.step("client", "Run the client").dependOn(&run_client.step);
    
    // Tests
    const tests = b.addTest(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}
```

---

## Part 9: Implementation Roadmap

### Phase 1: Foundation (2-3 months)
- [ ] BLAZE basic Vulkan setup (context, swapchain, pipelines)
- [ ] FLUX text rendering and basic widgets
- [ ] ECS implementation with basic components
- [ ] Packet serialization/deserialization
- [ ] Basic TCP networking (single server)
- [ ] SQLite database layer
- [ ] Login flow (account creation, character select)

### Phase 2: Rendering (2-3 months)
- [ ] FORGE scene graph and GPU culling
- [ ] Terrain rendering with LOD
- [ ] Character rendering (static poses)
- [ ] Basic FLUX HUD (health bars, hotbars)
- [ ] Zone loading and spatial partitioning

### Phase 3: World (2-3 months)
- [ ] Player movement with client prediction
- [ ] Entity interpolation
- [ ] NPC spawning and basic AI (stand, wander)
- [ ] Chat system (say, group, guild)
- [ ] Skeletal animation system

### Phase 4: Combat (3-4 months)
- [ ] Melee combat formulas
- [ ] Weapon styles and positional attacks
- [ ] Basic spell casting
- [ ] Health/mana/endurance regeneration
- [ ] Death and respawn
- [ ] Combat effects (particles)

### Phase 5: Content (3-4 months)
- [ ] Complete class implementations (start with 3 base classes per realm)
- [ ] Spell system with all effect types
- [ ] Item system (equipping, stats, quality)
- [ ] NPC vendors and trainers
- [ ] Inventory and equipment UI

### Phase 6: RvR (3-4 months)
- [ ] Frontier zones
- [ ] Keep structures and siege
- [ ] Relic system
- [ ] Realm rank and abilities
- [ ] Large-scale battle optimization

### Phase 7: Framework Extraction (Ongoing)
- [ ] Document EMBER interfaces
- [ ] Separate DAoC-specific code from reusable framework
- [ ] Create example game template
- [ ] Write framework documentation

---

## Part 10: Performance Targets

### Original DAoC Baseline
- 4,000 players per server cluster
- 10 kbit/s per player (~1.25 KB/s)
- 50ms server tick (20 ticks/second)

### Zig Recreation Targets

**Server:**
- 10,000+ players per server (modern hardware, efficient ECS)
- 5 kbit/s per player (better compression, delta encoding)
- 16ms server tick (60 ticks/second for smoother combat)
- <500MB memory for full server

**Client:**
- 60fps minimum, 120fps+ target
- <1ms CPU frame time (after render)
- 100,000+ triangles per frame (characters, terrain, objects)
- <2GB VRAM usage

### GPU Performance Budget (Per Frame)
```
Terrain:        200k triangles (LOD)
Characters:     50 × 10k = 500k triangles
Objects:        1000 × 500 = 500k triangles
Effects:        100k particles
UI:             1000 quads, 5000 glyphs

Total:          ~1.2M triangles + 100k particles
Target:         2ms GPU time @ 1080p
```

---

## Part 11: The EMBER Game Framework

What we extract for reuse:

| Component | DAoC-Specific | EMBER Framework |
|-----------|---------------|-----------------|
| ECS | Component definitions | World, Archetype, Query, System |
| Networking | DAoC protocol | Connection, Packet, Serialization |
| Rendering | Character models | FORGE integration, SceneGraph |
| UI | HUD layout | FLUX widgets, Window system |
| Assets | MPK/NIF loaders | AssetManager, async loading |
| Audio | Sound effects | AudioSystem, 3D spatial |
| Input | Keybinds | InputManager, action mapping |
| Game Loop | Tick systems | Fixed timestep, interpolation |

### EMBER Usage Example (Future Game)

```zig
const ember = @import("ember");

const MyGame = struct {
    player: ember.Entity,
    enemies: std.ArrayList(ember.Entity),
    
    pub fn init(allocator: std.mem.Allocator, scene: *ember.Scene) !*MyGame {
        var self = try allocator.create(MyGame);
        
        // Spawn player
        self.player = try scene.spawn(.{
            .mesh = "player.gltf",
            .position = .{ 0, 0, 0 },
            .components = .{
                Health{ .current = 100, .max = 100 },
                Movement{ .speed = 5.0 },
            },
        });
        
        return self;
    }
    
    pub fn fixedUpdate(self: *MyGame, dt: f32) void {
        // Game logic at fixed rate
    }
    
    pub fn update(self: *MyGame, dt: f32) void {
        // Variable rate updates
    }
};

fn myGameUi(state: *MyGame) ember.flux.Element {
    return ember.flux.column(.{}, .{
        healthBar(state.player.get(Health)),
        // ... more UI
    });
}

pub fn main() !void {
    var app = try ember.GameApp(MyGame, .{
        .app_name = "My Game",
        .window_title = "My Game",
        .window_width = 1920,
        .window_height = 1080,
        .tick_rate = 60,
        .ui_view = myGameUi,
    }).init(std.heap.page_allocator);
    
    try app.run();
}
```

---

## Conclusion

Building DAoC in Zig with BLAZE/FORGE/FLUX achieves multiple goals:

1. **Learn GPU programming** - BLAZE abstracts Vulkan while teaching concepts
2. **Build a real game** - DAoC provides concrete requirements
3. **Create reusable tools** - EMBER framework for future projects
4. **Pure Zig stack** - No C++ dependencies, cross-compilation, comptime validation

The original game was built by 25 people in 18 months. A solo recreation focusing on core gameplay is realistic over 2-3 years of weekend work, with the bonus of having a reusable game framework at the end.

**Recommended first milestone**: Render a character standing in a zone with basic terrain, controlled by WASD, with health bars in FLUX. Everything else builds from there.

---

## Resources

- [OpenDAoC Source](https://github.com/OpenDAoC/OpenDAoC-Core) - Modern C# emulator
- [Dawn of Light](https://github.com/Dawn-of-Light/DOLSharp) - Original emulator project
- [Mythic Postmortem](https://www.gamedeveloper.com/business/postmortem-mythic-entertainment-s-i-dark-age-of-camelot-i-) - Original development insights
- [ZCS](https://github.com/Games-by-Mason/ZCS) - Production Zig ECS
- [Gaffer on Games](https://gafferongames.com/) - Game networking articles
- [Learn OpenGL](https://learnopengl.com/) - Concepts apply to Vulkan
- [Vulkan Guide](https://vkguide.dev/) - Vulkan learning resource
