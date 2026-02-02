# Rich Terminal Environment

A GPU-accelerated terminal emulator and computing environment built from scratch in Zig using the BLAZE/FLUX graphics stack.

## Vision

Not just another terminal emulator—a unified computing environment that combines:

- **Terminal emulator** with GPU-accelerated rendering via FLUX
- **Rich media support** (images, video playback via BLAZE + Vulkan Video)
- **Lite web browser** (HTML/CSS, no JavaScript)
- **Local search engine / indexer**
- **LLM integration** woven throughout

Target platforms: Linux (primary), Windows (secondary), Web/WASM (future via WebGPU backend)

---

## Concepts

### Terminal vs Terminal Emulator

**Terminal**: Originally physical hardware (VT100, etc.) connected to mainframes. Had a screen, keyboard, and understood escape sequence protocols.

**Terminal emulator**: Software that emulates that hardware—interprets escape sequences, manages a character grid, communicates with the OS via a PTY (pseudo-terminal).

In modern usage, "terminal" typically means "terminal emulator."

### The Stack

```
┌─────────────────────────────────────────────────────────────────┐
│  Shell (zsh, bash, fish)                                        │
├─────────────────────────────────────────────────────────────────┤
│  Multiplexer (tmux, zellij)            ← outputs escape seqs    │
├─────────────────────────────────────────────────────────────────┤
│  Terminal Emulator                     ← THIS PROJECT           │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  Terminal Logic (PTY, escape parser, grid state)           │ │
│  ├────────────────────────────────────────────────────────────┤ │
│  │  FLUX UI Layer (widgets, layout, input handling)           │ │
│  ├────────────────────────────────────────────────────────────┤ │
│  │  BLAZE GPU Layer (Vulkan abstraction, command encoding)    │ │
│  └────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│  PTY (kernel)                                                   │
└─────────────────────────────────────────────────────────────────┘
```

**Key insight**: tmux/zellij *output* escape sequences—they don't render. The terminal emulator *interprets* those sequences and draws pixels. Porting them first would be the wrong layer.

---

## Architecture

### High-Level Overview with BLAZE/FLUX

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              ENVIRONMENT                                 │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │
│  │  Terminal   │  │   Browser   │  │   Search    │  │   LLM Interface │ │
│  │  + Media    │  │   (lite)    │  │  + Index    │  │   + Chat Panel  │ │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └────────┬────────┘ │
│         │                │                │                   │         │
│         └────────────────┴────────────────┴───────────────────┘         │
│                                   │                                      │
│                          FLUX Application                                │
│                    (Layout, Widgets, Event Handling)                     │
├─────────────────────────────────────────────────────────────────────────┤
│                        SHARED INFRASTRUCTURE                             │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────┐  ┌────────────────┐ │
│  │    FLUX      │  │    BLAZE     │  │  Storage   │  │    Network     │ │
│  │  Renderer    │  │  GPU Core    │  │  + Cache   │  │     Stack      │ │
│  │ (text, quads)│  │  (Vulkan)    │  │            │  │                │ │
│  └──────────────┘  └──────────────┘  └────────────┘  └────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

### Graphics Stack Integration

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Terminal Application                              │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                    Application State                                │ │
│  │  - PTY connection                                                   │ │
│  │  - Terminal grid (cells, colors, attributes)                        │ │
│  │  - Scrollback buffer                                                │ │
│  │  - Selection state                                                  │ │
│  │  - UI panels (tabs, splits, search overlay)                         │ │
│  └────────────────────────────────────────────────────────────────────┘ │
└───────────────────────────────────┬─────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                              FLUX                                        │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────────────────┐ │
│  │  Element Tree  │  │    Layout      │  │      Paint / Draw          │ │
│  │  - TermGrid    │  │  - Flexbox     │  │  - Glyph instances         │ │
│  │  - TabBar      │  │  - Constraint  │  │  - Quad instances          │ │
│  │  - ScrollView  │  │  - Measure     │  │  - Clip rects              │ │
│  │  - Overlay     │  │  - Position    │  │  - Image textures          │ │
│  └────────────────┘  └────────────────┘  └────────────────────────────┘ │
│                                                        │                 │
│                                                        ▼                 │
│  ┌─────────────────────────────────────────────────────────────────────┐│
│  │                        FLUX Renderer                                 ││
│  │  - SDF text rendering (crisp at any scale)                          ││
│  │  - Instanced quad batching (backgrounds, cursors, selections)       ││
│  │  - Texture atlas management (glyphs, images)                        ││
│  │  - Clip stack for scrolling regions                                 ││
│  └─────────────────────────────────────────────────────────────────────┘│
└───────────────────────────────────┬─────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                              BLAZE                                       │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────────────────┐ │
│  │    Context     │  │   Pipelines    │  │     Command Encoder        │ │
│  │  - Vulkan init │  │  - Glyph       │  │  - beginRenderPass         │ │
│  │  - Swapchain   │  │  - Quad        │  │  - setPipeline             │ │
│  │  - Memory      │  │  - Image       │  │  - setBindGroup            │ │
│  │  - Sync        │  │  - Video frame │  │  - draw (instanced)        │ │
│  └────────────────┘  └────────────────┘  └────────────────────────────┘ │
│                                                        │                 │
│                                                        ▼                 │
│                                                   Vulkan API             │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## FLUX Components for Terminal

### Custom Terminal Widget

The terminal grid is a custom FLUX element that handles the unique requirements of terminal rendering:

```zig
// terminal/widgets/term_grid.zig

const std = @import("std");
const flux = @import("flux");

/// Terminal grid cell
pub const Cell = struct {
    char: u21,              // Unicode codepoint
    fg: Color,              // Foreground color
    bg: Color,              // Background color  
    attrs: Attributes,      // Bold, italic, underline, etc.
    
    pub const Attributes = packed struct {
        bold: bool = false,
        italic: bool = false,
        underline: bool = false,
        strikethrough: bool = false,
        inverse: bool = false,
        blink: bool = false,
        dim: bool = false,
        hidden: bool = false,
    };
};

/// Terminal grid state
pub const TerminalGrid = struct {
    cols: u32,
    rows: u32,
    cells: []Cell,                    // Current visible grid (cols × rows)
    scrollback: ScrollbackBuffer,     // Historical lines
    cursor: Cursor,
    selection: ?Selection,
    
    // Dirty tracking for incremental updates
    dirty_lines: std.DynamicBitSet,
    
    pub const Cursor = struct {
        col: u32,
        row: u32,
        style: CursorStyle,
        visible: bool,
        blink_state: bool,
    };
    
    pub const CursorStyle = enum { block, underline, bar };
};

/// Custom FLUX element for terminal rendering
pub const TermGridElement = struct {
    grid: *TerminalGrid,
    font: *flux.Font,
    cell_size: flux.Size,
    
    /// FLUX layout callback
    pub fn layout(self: *TermGridElement, constraints: flux.Constraints) flux.Size {
        // Terminal wants exact size based on cell count
        return .{
            .width = @as(f32, @floatFromInt(self.grid.cols)) * self.cell_size.width,
            .height = @as(f32, @floatFromInt(self.grid.rows)) * self.cell_size.height,
        };
    }
    
    /// FLUX paint callback - emits draw commands
    pub fn paint(self: *TermGridElement, rect: flux.Rect, draw_list: *flux.DrawList) void {
        const grid = self.grid;
        
        // Only render visible lines (virtualization)
        const first_visible_row: u32 = 0;  // Adjust for scroll offset
        const last_visible_row: u32 = grid.rows;
        
        // Background pass - batch all backgrounds
        for (first_visible_row..last_visible_row) |row| {
            for (0..grid.cols) |col| {
                const cell = grid.getCell(col, row);
                const cell_rect = self.cellRect(col, row, rect);
                
                // Only draw non-default backgrounds
                if (!cell.bg.eql(self.default_bg)) {
                    draw_list.addQuad(cell_rect, .{
                        .color = cell.bg,
                        .border_radius = 0,
                    });
                }
            }
        }
        
        // Selection overlay
        if (grid.selection) |sel| {
            self.paintSelection(sel, rect, draw_list);
        }
        
        // Text pass - batch all glyphs
        for (first_visible_row..last_visible_row) |row| {
            for (0..grid.cols) |col| {
                const cell = grid.getCell(col, row);
                
                if (cell.char != ' ' and cell.char != 0) {
                    const pos = self.cellPosition(col, row, rect);
                    const style = self.cellTextStyle(cell);
                    
                    // FLUX handles glyph atlas lookup and batching
                    draw_list.addGlyph(cell.char, pos, style, self.font);
                }
            }
        }
        
        // Cursor
        if (grid.cursor.visible and grid.cursor.blink_state) {
            self.paintCursor(grid.cursor, rect, draw_list);
        }
    }
    
    fn cellRect(self: *TermGridElement, col: usize, row: usize, container: flux.Rect) flux.Rect {
        return .{
            .x = container.x + @as(f32, @floatFromInt(col)) * self.cell_size.width,
            .y = container.y + @as(f32, @floatFromInt(row)) * self.cell_size.height,
            .width = self.cell_size.width,
            .height = self.cell_size.height,
        };
    }
    
    fn paintCursor(self: *TermGridElement, cursor: Cursor, rect: flux.Rect, draw_list: *flux.DrawList) void {
        const cell_rect = self.cellRect(cursor.col, cursor.row, rect);
        
        switch (cursor.style) {
            .block => {
                draw_list.addQuad(cell_rect, .{
                    .color = self.cursor_color,
                });
            },
            .underline => {
                draw_list.addQuad(.{
                    .x = cell_rect.x,
                    .y = cell_rect.y + cell_rect.height - 2,
                    .width = cell_rect.width,
                    .height = 2,
                }, .{ .color = self.cursor_color });
            },
            .bar => {
                draw_list.addQuad(.{
                    .x = cell_rect.x,
                    .y = cell_rect.y,
                    .width = 2,
                    .height = cell_rect.height,
                }, .{ .color = self.cursor_color });
            },
        }
    }
    
    fn paintSelection(self: *TermGridElement, sel: Selection, rect: flux.Rect, draw_list: *flux.DrawList) void {
        // Render selection highlight for each selected cell
        var row = sel.start_row;
        while (row <= sel.end_row) : (row += 1) {
            const start_col = if (row == sel.start_row) sel.start_col else 0;
            const end_col = if (row == sel.end_row) sel.end_col else self.grid.cols;
            
            const sel_rect = flux.Rect{
                .x = rect.x + @as(f32, @floatFromInt(start_col)) * self.cell_size.width,
                .y = rect.y + @as(f32, @floatFromInt(row)) * self.cell_size.height,
                .width = @as(f32, @floatFromInt(end_col - start_col)) * self.cell_size.width,
                .height = self.cell_size.height,
            };
            
            draw_list.addQuad(sel_rect, .{
                .color = self.selection_color,
            });
        }
    }
};
```

### Terminal Application Structure

```zig
// terminal/app.zig

const std = @import("std");
const flux = @import("flux");
const blaze = @import("blaze");
const pty = @import("pty.zig");
const parser = @import("escape_parser.zig");
const TermGridElement = @import("widgets/term_grid.zig").TermGridElement;

pub const TerminalState = struct {
    // PTY
    pty_fd: std.posix.fd_t,
    child_pid: std.posix.pid_t,
    
    // Terminal state
    grid: TerminalGrid,
    scrollback: ScrollbackBuffer,
    
    // UI state
    tabs: std.ArrayList(Tab),
    active_tab: usize,
    show_search: bool,
    search_query: []u8,
    
    // Settings
    font_size: f32,
    opacity: f32,
    
    pub fn processInput(self: *TerminalState, data: []const u8) void {
        // Parse escape sequences and update grid
        parser.parse(data, &self.grid);
    }
    
    pub fn resize(self: *TerminalState, cols: u32, rows: u32) void {
        self.grid.resize(cols, rows);
        
        // Notify PTY of new size
        pty.setSize(self.pty_fd, cols, rows);
    }
};

/// Main terminal view using FLUX
fn terminalView(state: *TerminalState) flux.Element {
    return flux.column(.{ .flex = 1 }, .{
        // Tab bar (if multiple tabs)
        if (state.tabs.items.len > 1)
            tabBar(state)
        else
            flux.empty(),
        
        // Main terminal content
        flux.container(.{ .flex = 1, .style = terminalContainerStyle(state) }, .{
            // Terminal grid (custom widget)
            flux.custom(.{
                .flex = 1,
                .element = TermGridElement{
                    .grid = &state.grid,
                    .font = state.font,
                    .cell_size = state.cell_size,
                },
            }),
            
            // Scrollbar (if scrollback)
            if (state.scrollback.len > 0)
                flux.scrollbar(.{
                    .total = state.scrollback.len + state.grid.rows,
                    .visible = state.grid.rows,
                    .position = state.scroll_offset,
                    .on_scroll = state.setScrollOffset,
                })
            else
                flux.empty(),
        }),
        
        // Search overlay (if active)
        if (state.show_search)
            searchOverlay(state)
        else
            flux.empty(),
    });
}

fn tabBar(state: *TerminalState) flux.Element {
    var tabs_elements: [32]flux.Element = undefined;
    
    for (state.tabs.items, 0..) |tab, i| {
        tabs_elements[i] = flux.button(tab.title, .{
            .style = if (i == state.active_tab) styles.active_tab else styles.inactive_tab,
            .on_click = flux.callback(state, struct {
                fn click(s: *TerminalState, idx: usize) void {
                    s.active_tab = idx;
                }
            }.click, i),
        });
    }
    
    return flux.row(.{ .style = styles.tab_bar }, tabs_elements[0..state.tabs.items.len]);
}

fn searchOverlay(state: *TerminalState) flux.Element {
    return flux.container(.{ .style = styles.search_overlay }, .{
        flux.row(.{ .gap = 8, .align_items = .center }, .{
            flux.text("Find:", .{}),
            flux.input(&state.search_query, .{
                .placeholder = "Search...",
                .on_change = state.updateSearch,
                .on_submit = state.findNext,
            }),
            flux.button("↑", .{ .on_click = state.findPrev }),
            flux.button("↓", .{ .on_click = state.findNext }),
            flux.button("✕", .{ .on_click = state.closeSearch }),
        }),
    });
}

/// Main entry point
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Initialize BLAZE context
    var blaze_ctx = try blaze.Context.init(allocator, .{
        .app_name = "RichTerm",
        .validation = std.builtin.mode == .Debug,
    });
    defer blaze_ctx.deinit();
    
    // Initialize terminal state
    var state = try TerminalState.init(allocator);
    defer state.deinit();
    
    // Spawn shell
    try state.spawnShell("/bin/zsh");
    
    // Run FLUX application
    const App = flux.App(TerminalState, terminalView);
    var app = try App.init(allocator, state, .{
        .title = "RichTerm",
        .width = 1280,
        .height = 800,
        .blaze_context = &blaze_ctx,
    });
    defer app.deinit();
    
    // Custom event loop to handle PTY reads
    while (!app.shouldClose()) {
        // Poll PTY for new data
        if (try state.pollPty()) |data| {
            state.processInput(data);
            app.requestRedraw();
        }
        
        // Process FLUX events and render
        try app.processEvents();
        try app.render();
    }
}
```

---

## Shared Components (Build Once, Use Everywhere)

### Text Engine (Part of FLUX)

FLUX provides the text rendering infrastructure:

```zig
// From FLUX - used by terminal, browser, search UI, LLM chat

pub const Font = struct {
    atlas: blaze.Texture,           // SDF glyph atlas
    glyphs: std.AutoHashMap(u21, Glyph),
    
    line_height: f32,
    ascender: f32,
    descender: f32,
    
    // For terminal: monospace metrics
    cell_width: f32,                // All glyphs same width
    cell_height: f32,
    
    pub fn load(ctx: *blaze.Context, path: []const u8, size: f32) !Font {
        // 1. Load TTF with FreeType
        // 2. Rasterize glyphs to SDF
        // 3. Pack into atlas texture
        // 4. Upload to GPU via BLAZE
    }
    
    pub fn getGlyph(self: *Font, codepoint: u21) ?Glyph {
        return self.glyphs.get(codepoint);
    }
};

pub const Glyph = struct {
    uv_min: [2]f32,     // Atlas texture coordinates
    uv_max: [2]f32,
    size: [2]f32,       // Glyph dimensions
    bearing: [2]f32,    // Offset from baseline
    advance: f32,       // Horizontal advance
};
```

### BLAZE Renderer (GPU Abstraction)

BLAZE handles all GPU operations:

```zig
// Terminal uses BLAZE for:
// 1. Glyph quad rendering (instanced)
// 2. Background/selection quads
// 3. Image textures (inline images)
// 4. Video frame decode (Vulkan Video extension)

const TerminalRenderer = struct {
    ctx: *blaze.Context,
    
    // FLUX renderer (handles text/quads)
    flux_renderer: *flux.Renderer,
    
    // Additional pipelines for terminal-specific rendering
    image_pipeline: blaze.Pipeline,
    video_pipeline: ?blaze.Pipeline,  // If Vulkan Video available
    
    // Texture management
    image_cache: ImageCache,
    
    pub fn init(ctx: *blaze.Context) !TerminalRenderer {
        var flux_renderer = try flux.Renderer.init(ctx);
        
        // Check for Vulkan Video support
        const video_pipeline = if (ctx.hasFeature(.video_decode))
            try createVideoPipeline(ctx)
        else
            null;
        
        return .{
            .ctx = ctx,
            .flux_renderer = flux_renderer,
            .image_pipeline = try createImagePipeline(ctx),
            .video_pipeline = video_pipeline,
            .image_cache = ImageCache.init(ctx.allocator),
        };
    }
    
    pub fn render(self: *TerminalRenderer, draw_list: *flux.DrawList, target: blaze.TextureView) void {
        // FLUX renderer handles text and basic quads
        self.flux_renderer.render(draw_list, target);
        
        // Handle inline images separately
        self.renderInlineImages(target);
    }
};
```

### Storage Layer

```zig
// storage/store.zig

pub const ContentStore = struct {
    db: sqlite.Database,
    data_dir: []const u8,
    
    /// Store content by hash (deduplication)
    pub fn store(self: *ContentStore, data: []const u8) ![32]u8 {
        const hash = std.crypto.hash.sha256.hash(data);
        
        // Check if already exists
        if (!self.exists(hash)) {
            // Write to disk
            const path = self.hashToPath(hash);
            try std.fs.writeFileZ(path, data);
            
            // Index in database
            try self.db.exec("INSERT INTO content (hash, size) VALUES (?, ?)", .{
                &hash, data.len,
            });
        }
        
        return hash;
    }
    
    /// Retrieve content by hash
    pub fn get(self: *ContentStore, hash: [32]u8) !?[]const u8 {
        const path = self.hashToPath(hash);
        return std.fs.readFileAllocZ(self.allocator, path) catch null;
    }
};

// Used by:
// - Terminal scrollback (offload old lines to disk)
// - Browser cache (page content, images)
// - Search index (document storage)
// - LLM context (conversation history)
```

### Network Stack

```zig
// network/http.zig

pub const HttpClient = struct {
    allocator: Allocator,
    tls_context: *bearssl.Context,
    
    pub fn get(self: *HttpClient, url: []const u8) !Response {
        const parsed = try Uri.parse(url);
        
        // Establish connection
        var socket = try std.net.tcpConnectToHost(parsed.host, parsed.port);
        defer socket.close();
        
        // TLS handshake if HTTPS
        if (parsed.scheme == .https) {
            try self.tls_context.wrap(&socket);
        }
        
        // Send request
        try socket.writeAll(self.buildRequest(parsed));
        
        // Read response
        return try self.parseResponse(socket);
    }
};

// Used by:
// - Browser (page fetching)
// - LLM APIs (OpenAI, Anthropic, local)
// - Search crawling (optional)
```

---

## Component Details

### Terminal Emulator Core

**PTY Management**

```zig
// terminal/pty.zig

pub fn spawn(shell: []const u8, env: []const [*:0]const u8) !PtyPair {
    var master_fd: std.posix.fd_t = undefined;
    var slave_fd: std.posix.fd_t = undefined;
    
    // Open PTY pair
    try std.posix.openpty(&master_fd, &slave_fd, null, null, null);
    
    const pid = try std.posix.fork();
    
    if (pid == 0) {
        // Child process
        std.posix.close(master_fd);
        
        // Create new session, set controlling terminal
        _ = std.posix.setsid();
        _ = std.c.ioctl(slave_fd, std.c.TIOCSCTTY, @as(c_ulong, 0));
        
        // Redirect stdio
        std.posix.dup2(slave_fd, 0);  // stdin
        std.posix.dup2(slave_fd, 1);  // stdout
        std.posix.dup2(slave_fd, 2);  // stderr
        
        // Exec shell
        std.posix.execvpeZ(shell, &.{shell}, env);
    }
    
    // Parent process
    std.posix.close(slave_fd);
    
    return .{
        .master_fd = master_fd,
        .child_pid = pid,
    };
}

pub fn setSize(fd: std.posix.fd_t, cols: u16, rows: u16) !void {
    var ws = std.posix.winsize{
        .ws_col = cols,
        .ws_row = rows,
        .ws_xpixel = 0,
        .ws_ypixel = 0,
    };
    _ = std.c.ioctl(fd, std.c.TIOCSWINSZ, &ws);
}
```

**Escape Sequence Parser**

```zig
// terminal/escape_parser.zig

pub const Parser = struct {
    state: State,
    params: [16]u16,
    param_count: u8,
    intermediate: [4]u8,
    intermediate_count: u8,
    
    const State = enum {
        ground,
        escape,
        escape_intermediate,
        csi_entry,
        csi_param,
        csi_intermediate,
        osc_string,
        dcs_entry,
        // ... more states for full xterm compatibility
    };
    
    pub fn parse(self: *Parser, data: []const u8, grid: *TerminalGrid) void {
        for (data) |byte| {
            self.processByte(byte, grid);
        }
    }
    
    fn processByte(self: *Parser, byte: u8, grid: *TerminalGrid) void {
        switch (self.state) {
            .ground => {
                if (byte == 0x1B) {
                    self.state = .escape;
                } else if (byte >= 0x20 and byte < 0x7F) {
                    // Printable character
                    grid.putChar(byte);
                } else {
                    // Control character
                    self.handleControl(byte, grid);
                }
            },
            .escape => {
                switch (byte) {
                    '[' => self.state = .csi_entry,
                    ']' => self.state = .osc_string,
                    '(' => self.state = .escape_intermediate,
                    // ... handle other escape sequences
                    else => self.state = .ground,
                }
            },
            .csi_entry, .csi_param => {
                if (byte >= '0' and byte <= '9') {
                    // Accumulate parameter
                    self.params[self.param_count] *= 10;
                    self.params[self.param_count] += byte - '0';
                    self.state = .csi_param;
                } else if (byte == ';') {
                    self.param_count += 1;
                } else if (byte >= 0x40 and byte <= 0x7E) {
                    // Final byte - execute command
                    self.executeCsi(byte, grid);
                    self.reset();
                }
            },
            // ... other states
        }
    }
    
    fn executeCsi(self: *Parser, final: u8, grid: *TerminalGrid) void {
        switch (final) {
            'm' => self.handleSgr(grid),           // Colors/attributes
            'H', 'f' => self.handleCup(grid),      // Cursor position
            'A' => grid.moveCursorUp(self.param(0, 1)),
            'B' => grid.moveCursorDown(self.param(0, 1)),
            'C' => grid.moveCursorRight(self.param(0, 1)),
            'D' => grid.moveCursorLeft(self.param(0, 1)),
            'J' => self.handleEd(grid),            // Erase display
            'K' => self.handleEl(grid),            // Erase line
            // ... many more CSI commands
            else => {},
        }
    }
    
    fn handleSgr(self: *Parser, grid: *TerminalGrid) void {
        // SGR - Select Graphic Rendition (colors, bold, etc.)
        var i: usize = 0;
        while (i <= self.param_count) : (i += 1) {
            const p = self.params[i];
            switch (p) {
                0 => grid.resetAttributes(),
                1 => grid.setBold(true),
                3 => grid.setItalic(true),
                4 => grid.setUnderline(true),
                7 => grid.setInverse(true),
                30...37 => grid.setFg(basicColors[p - 30]),
                40...47 => grid.setBg(basicColors[p - 40]),
                38 => {
                    // Extended foreground color (256 or RGB)
                    i += 1;
                    if (self.params[i] == 5) {
                        // 256 color
                        i += 1;
                        grid.setFg(color256[self.params[i]]);
                    } else if (self.params[i] == 2) {
                        // RGB
                        grid.setFg(.{
                            .r = @intCast(self.params[i + 1]),
                            .g = @intCast(self.params[i + 2]),
                            .b = @intCast(self.params[i + 3]),
                            .a = 255,
                        });
                        i += 3;
                    }
                },
                // ... more SGR codes
                else => {},
            }
        }
    }
};
```

**Terminal State**

```zig
// terminal/grid.zig

pub const TerminalGrid = struct {
    allocator: Allocator,
    
    // Current screen
    cols: u32,
    rows: u32,
    cells: []Cell,
    
    // Cursor
    cursor_col: u32,
    cursor_row: u32,
    
    // Attributes for new characters
    current_fg: Color,
    current_bg: Color,
    current_attrs: Cell.Attributes,
    
    // Scrollback
    scrollback: ScrollbackBuffer,
    scroll_offset: i32,           // 0 = bottom, negative = scrolled up
    
    // Dirty tracking for efficient rendering
    dirty_lines: std.DynamicBitSet,
    
    pub fn putChar(self: *TerminalGrid, char: u21) void {
        if (self.cursor_col >= self.cols) {
            self.lineFeed();
            self.cursor_col = 0;
        }
        
        const idx = self.cursor_row * self.cols + self.cursor_col;
        self.cells[idx] = .{
            .char = char,
            .fg = self.current_fg,
            .bg = self.current_bg,
            .attrs = self.current_attrs,
        };
        
        self.dirty_lines.set(self.cursor_row);
        self.cursor_col += 1;
    }
    
    pub fn lineFeed(self: *TerminalGrid) void {
        if (self.cursor_row < self.rows - 1) {
            self.cursor_row += 1;
        } else {
            // Scroll: move top line to scrollback, shift everything up
            self.scrollback.pushLine(self.cells[0..self.cols]);
            
            std.mem.copyForwards(
                Cell,
                self.cells[0..(self.rows - 1) * self.cols],
                self.cells[self.cols..],
            );
            
            // Clear bottom line
            @memset(self.cells[(self.rows - 1) * self.cols..], Cell.blank());
            
            // Mark all lines dirty
            self.dirty_lines.setAll();
        }
    }
    
    pub fn resize(self: *TerminalGrid, new_cols: u32, new_rows: u32) void {
        const new_cells = self.allocator.alloc(Cell, new_cols * new_rows) catch return;
        @memset(new_cells, Cell.blank());
        
        // Copy existing content (handling size changes)
        const copy_cols = @min(self.cols, new_cols);
        const copy_rows = @min(self.rows, new_rows);
        
        for (0..copy_rows) |row| {
            const src_start = row * self.cols;
            const dst_start = row * new_cols;
            @memcpy(
                new_cells[dst_start..dst_start + copy_cols],
                self.cells[src_start..src_start + copy_cols],
            );
        }
        
        self.allocator.free(self.cells);
        self.cells = new_cells;
        self.cols = new_cols;
        self.rows = new_rows;
        
        // Clamp cursor
        self.cursor_col = @min(self.cursor_col, new_cols - 1);
        self.cursor_row = @min(self.cursor_row, new_rows - 1);
        
        // Resize dirty tracking
        self.dirty_lines.resize(new_rows, true) catch {};
    }
};

pub const ScrollbackBuffer = struct {
    lines: std.ArrayList([]Cell),
    max_lines: usize,
    
    pub fn pushLine(self: *ScrollbackBuffer, line: []const Cell) void {
        if (self.lines.items.len >= self.max_lines) {
            // Evict oldest line
            self.allocator.free(self.lines.orderedRemove(0));
        }
        
        const copy = self.allocator.dupe(Cell, line) catch return;
        self.lines.append(copy) catch return;
    }
    
    pub fn getLine(self: *ScrollbackBuffer, index: usize) ?[]const Cell {
        if (index >= self.lines.items.len) return null;
        return self.lines.items[index];
    }
};
```

### Rich Media Rendering

```
┌────────────────────────────────────────────────────────────────┐
│  Terminal Window                                                │
│  ┌────────────────────────────┐  ┌────────────────────────────┐│
│  │ $ cat video.mp4            │  │                            ││
│  │ Playing...                 │  │       ▶ VIDEO FRAME        ││
│  │                            │  │     (BLAZE texture)        ││
│  │ $ ls                       │  │                            ││
│  │ file1.txt  file2.txt       │  └────────────────────────────┘│
│  └────────────────────────────┘                                 │
│           ↑                                    ↑                │
│    FLUX glyph quads                   BLAZE image/video        │
│           └────────── Same render pass ───────┘                │
└────────────────────────────────────────────────────────────────┘
```

**Kitty Graphics Protocol Integration**

```zig
// terminal/graphics.zig

pub const GraphicsManager = struct {
    ctx: *blaze.Context,
    images: std.AutoHashMap(u32, Image),
    placements: std.ArrayList(Placement),
    
    pub const Image = struct {
        id: u32,
        texture: blaze.Texture,
        width: u32,
        height: u32,
    };
    
    pub const Placement = struct {
        image_id: u32,
        col: u32,
        row: u32,
        width_cells: u32,
        height_cells: u32,
        z_index: i32,
    };
    
    /// Handle Kitty graphics escape sequence
    pub fn handleGraphicsCommand(self: *GraphicsManager, cmd: GraphicsCommand) !void {
        switch (cmd.action) {
            .transmit => {
                // Receive image data
                const decoded = try self.decodeImage(cmd.data, cmd.format);
                const texture = try self.uploadTexture(decoded);
                
                try self.images.put(cmd.id, .{
                    .id = cmd.id,
                    .texture = texture,
                    .width = decoded.width,
                    .height = decoded.height,
                });
            },
            .put => {
                // Place image in terminal
                try self.placements.append(.{
                    .image_id = cmd.id,
                    .col = cmd.col,
                    .row = cmd.row,
                    .width_cells = cmd.width_cells orelse 0,
                    .height_cells = cmd.height_cells orelse 0,
                    .z_index = cmd.z_index orelse 0,
                });
            },
            .delete => {
                // Remove image
                if (self.images.fetchRemove(cmd.id)) |entry| {
                    self.ctx.destroyTexture(entry.value.texture);
                }
            },
            .query => {
                // Respond with capabilities
            },
        }
    }
    
    fn uploadTexture(self: *GraphicsManager, data: DecodedImage) !blaze.Texture {
        const texture = try self.ctx.createTexture(.{
            .extent = .{ .width = data.width, .height = data.height, .depth = 1 },
            .format = .rgba8_srgb,
            .usage = .{ .sampled = true, .transfer_dst = true },
        });
        
        try self.ctx.uploadTexture(texture, data.pixels);
        
        return texture;
    }
    
    /// Render all image placements
    pub fn render(self: *GraphicsManager, encoder: *blaze.Encoder, cell_size: Size) void {
        for (self.placements.items) |placement| {
            const image = self.images.get(placement.image_id) orelse continue;
            
            const rect = Rect{
                .x = @as(f32, @floatFromInt(placement.col)) * cell_size.width,
                .y = @as(f32, @floatFromInt(placement.row)) * cell_size.height,
                .width = @as(f32, @floatFromInt(placement.width_cells)) * cell_size.width,
                .height = @as(f32, @floatFromInt(placement.height_cells)) * cell_size.height,
            };
            
            // Draw textured quad
            encoder.setPipeline(self.image_pipeline);
            encoder.setBindGroup(0, self.createImageBindGroup(image.texture));
            encoder.pushConstants(.{ .rect = rect });
            encoder.draw(4, 1);  // Quad
        }
    }
};
```

**Video Pipeline with BLAZE**

```zig
// terminal/video.zig

pub const VideoPlayer = struct {
    ctx: *blaze.Context,
    
    // Vulkan Video decode (if available)
    video_session: ?blaze.VideoSession,
    
    // Fallback decoder
    ffmpeg_decoder: ?*FFmpegDecoder,
    
    // Frame management
    frame_textures: [3]blaze.Texture,  // Triple buffer
    current_frame: usize,
    
    // Timing
    pts_queue: std.PriorityQueue(Frame, void, compareFrames),
    start_time: i64,
    
    pub fn init(ctx: *blaze.Context, width: u32, height: u32, codec: Codec) !VideoPlayer {
        var self = VideoPlayer{
            .ctx = ctx,
            .video_session = null,
            .ffmpeg_decoder = null,
            .frame_textures = undefined,
            .current_frame = 0,
            .pts_queue = std.PriorityQueue(Frame, void, compareFrames).init(ctx.allocator, {}),
            .start_time = 0,
        };
        
        // Try Vulkan Video first
        if (ctx.hasFeature(.video_decode)) {
            self.video_session = try ctx.createVideoSession(.{
                .codec = codec,
                .width = width,
                .height = height,
            });
        } else {
            // Fallback to FFmpeg
            self.ffmpeg_decoder = try FFmpegDecoder.init(codec);
        }
        
        // Create frame textures
        for (&self.frame_textures) |*tex| {
            tex.* = try ctx.createTexture(.{
                .extent = .{ .width = width, .height = height, .depth = 1 },
                .format = .rgba8_unorm,
                .usage = .{ .sampled = true, .transfer_dst = true, .video_decode_dst = true },
            });
        }
        
        return self;
    }
    
    pub fn submitPacket(self: *VideoPlayer, packet: []const u8, pts: i64) !void {
        if (self.video_session) |session| {
            // Hardware decode path
            const frame_idx = self.current_frame;
            self.current_frame = (self.current_frame + 1) % 3;
            
            try self.ctx.decodeVideoFrame(session, packet, self.frame_textures[frame_idx]);
            
            try self.pts_queue.add(.{
                .texture_idx = frame_idx,
                .pts = pts,
            });
        } else if (self.ffmpeg_decoder) |decoder| {
            // Software decode path
            const frame = try decoder.decode(packet);
            defer frame.unref();
            
            const frame_idx = self.current_frame;
            self.current_frame = (self.current_frame + 1) % 3;
            
            // Upload to GPU
            try self.ctx.uploadTexture(
                self.frame_textures[frame_idx],
                frame.data,
            );
            
            try self.pts_queue.add(.{
                .texture_idx = frame_idx,
                .pts = pts,
            });
        }
    }
    
    pub fn getCurrentFrame(self: *VideoPlayer) ?blaze.Texture {
        const now = std.time.milliTimestamp() - self.start_time;
        
        // Find frame with PTS <= now
        while (self.pts_queue.peek()) |frame| {
            if (frame.pts <= now) {
                _ = self.pts_queue.remove();
                return self.frame_textures[frame.texture_idx];
            } else {
                break;
            }
        }
        
        return null;
    }
};
```

### Lite Browser

**Architecture with FLUX**

```zig
// browser/browser.zig

pub const BrowserState = struct {
    // Navigation
    current_url: []u8,
    history: std.ArrayList([]u8),
    history_idx: usize,
    
    // Page content
    dom: ?*DomNode,
    layout_tree: ?*LayoutBox,
    
    // Rendering
    scroll_y: f32,
    
    // Network
    http_client: HttpClient,
    
    pub fn navigate(self: *BrowserState, url: []const u8) !void {
        // Fetch page
        const response = try self.http_client.get(url);
        
        // Parse HTML
        const dom = try html.parse(response.body);
        
        // Build layout tree
        const layout = try layout.build(dom);
        
        self.dom = dom;
        self.layout_tree = layout;
        self.scroll_y = 0;
    }
};

/// Browser view using FLUX
fn browserView(state: *BrowserState) flux.Element {
    return flux.column(.{ .flex = 1 }, .{
        // Address bar
        flux.row(.{ .style = styles.address_bar, .gap = 8 }, .{
            flux.button("←", .{ .on_click = state.goBack, .disabled = state.history_idx == 0 }),
            flux.button("→", .{ .on_click = state.goForward }),
            flux.button("↻", .{ .on_click = state.reload }),
            flux.input(&state.current_url, .{
                .flex = 1,
                .on_submit = state.navigate,
            }),
        }),
        
        // Content area
        flux.scroll(.{ .flex = 1, .scroll_y = true }, .{
            // Render DOM/layout tree
            if (state.layout_tree) |layout|
                renderLayoutTree(layout)
            else
                flux.text("Loading...", .{}),
        }),
    });
}

fn renderLayoutTree(box: *LayoutBox) flux.Element {
    // Convert CSS layout tree to FLUX elements
    switch (box.node.tag) {
        .text => {
            return flux.text(box.node.text, .{
                .style = cssToFluxStyle(box.computed_style),
            });
        },
        .div, .p, .section => {
            var children: [64]flux.Element = undefined;
            var count: usize = 0;
            
            for (box.children.items) |child| {
                children[count] = renderLayoutTree(child);
                count += 1;
            }
            
            return flux.container(.{
                .style = cssToFluxStyle(box.computed_style),
            }, children[0..count]);
        },
        .img => {
            return flux.image(box.node.src, .{
                .width = box.width,
                .height = box.height,
            });
        },
        // ... other elements
    }
}
```

### Search Engine / Indexer

```zig
// search/indexer.zig

pub const SearchIndex = struct {
    db: sqlite.Database,
    inverted_index: std.StringHashMap(std.ArrayList(DocId)),
    embeddings: ?*VectorStore,  // sqlite-vec for semantic search
    
    pub fn indexFile(self: *SearchIndex, path: []const u8) !void {
        // Read file content
        const content = try std.fs.cwd().readFileAlloc(self.allocator, path, 10 * 1024 * 1024);
        defer self.allocator.free(content);
        
        // Extract text (handle different formats)
        const text = switch (detectFormat(path)) {
            .plain_text => content,
            .pdf => try extractPdfText(content),
            .html => try extractHtmlText(content),
            else => return,
        };
        
        // Store document
        const doc_id = try self.storeDocument(path, content);
        
        // Tokenize and index
        var tokenizer = Tokenizer.init(text);
        while (tokenizer.next()) |token| {
            const stemmed = stem(token);
            
            var docs = self.inverted_index.getOrPut(stemmed) catch continue;
            if (!docs.found_existing) {
                docs.value_ptr.* = std.ArrayList(DocId).init(self.allocator);
            }
            try docs.value_ptr.append(doc_id);
        }
        
        // Generate embedding for semantic search
        if (self.embeddings) |embeddings| {
            const embedding = try self.generateEmbedding(text);
            try embeddings.insert(doc_id, embedding);
        }
    }
    
    pub fn search(self: *SearchIndex, query: []const u8) ![]SearchResult {
        var results = std.ArrayList(SearchResult).init(self.allocator);
        
        // Keyword search
        var tokenizer = Tokenizer.init(query);
        var doc_scores = std.AutoHashMap(DocId, f32).init(self.allocator);
        
        while (tokenizer.next()) |token| {
            const stemmed = stem(token);
            
            if (self.inverted_index.get(stemmed)) |docs| {
                for (docs.items) |doc_id| {
                    const entry = doc_scores.getOrPut(doc_id) catch continue;
                    if (!entry.found_existing) {
                        entry.value_ptr.* = 0;
                    }
                    entry.value_ptr.* += 1;  // TF-IDF would be better
                }
            }
        }
        
        // Semantic search (if available)
        if (self.embeddings) |embeddings| {
            const query_embedding = try self.generateEmbedding(query);
            const similar = try embeddings.search(query_embedding, 10);
            
            for (similar) |result| {
                const entry = doc_scores.getOrPut(result.doc_id) catch continue;
                if (!entry.found_existing) {
                    entry.value_ptr.* = 0;
                }
                entry.value_ptr.* += result.similarity * 10;  // Weight semantic results
            }
        }
        
        // Sort by score
        var scored: []ScoredDoc = ...;
        std.sort.sort(ScoredDoc, scored, {}, compareScoredDocs);
        
        return results.toOwnedSlice();
    }
};
```

### LLM Integration

```zig
// llm/client.zig

pub const LlmClient = struct {
    http: HttpClient,
    provider: Provider,
    api_key: []const u8,
    
    pub const Provider = enum {
        openai,
        anthropic,
        local_ollama,
    };
    
    pub fn complete(self: *LlmClient, messages: []const Message) ![]const u8 {
        const body = switch (self.provider) {
            .anthropic => try self.buildAnthropicRequest(messages),
            .openai => try self.buildOpenAIRequest(messages),
            .local_ollama => try self.buildOllamaRequest(messages),
        };
        
        const response = try self.http.post(self.endpoint(), body, .{
            .authorization = self.authHeader(),
        });
        
        return try self.parseResponse(response.body);
    }
    
    pub fn stream(self: *LlmClient, messages: []const Message, callback: *const fn ([]const u8) void) !void {
        // Stream response chunks
        const body = switch (self.provider) {
            .anthropic => try self.buildAnthropicRequest(messages),
            // ...
        };
        
        try self.http.postStreaming(self.endpoint(), body, .{
            .authorization = self.authHeader(),
        }, struct {
            fn onChunk(chunk: []const u8) void {
                // Parse SSE chunk, extract text
                const text = parseStreamChunk(chunk);
                callback(text);
            }
        }.onChunk);
    }
};

// Integration with terminal
pub fn pipeLlm(terminal: *TerminalState, input: []const u8) !void {
    const messages = &.{
        .{ .role = .user, .content = input },
    };
    
    // Stream response directly to terminal
    try terminal.llm_client.stream(messages, struct {
        fn onChunk(terminal_ptr: *TerminalState, text: []const u8) void {
            terminal_ptr.writeToOutput(text);
        }
    }.onChunk);
}
```

---

## Why BLAZE/FLUX?

| Consideration | Raw Vulkan | BLAZE/FLUX |
|---------------|------------|------------|
| **Learning** | Maximum learning, maximum boilerplate | Still learn GPU concepts, less tedium |
| **Text rendering** | Build from scratch | FLUX has SDF text, glyph atlas, batching |
| **UI components** | Build from scratch | FLUX has layout, input handling, widgets |
| **Code reuse** | One-off terminal code | Same stack for browser, search UI, LLM chat |
| **WebAssembly** | Separate port needed | BLAZE WebGPU backend enables web version |
| **Iteration speed** | Slow (lots of boilerplate) | Fast (high-level APIs) |
| **Future projects** | Start over | FORGE for 3D, FLUX for any UI |

---

## Reference Projects

**Terminal Emulators**:
- **Ghostty** (Zig) - Mitchell Hashimoto's terminal, primary reference
- **Alacritty** (Rust) - GPU-accelerated, OpenGL
- **Kitty** (C/Python) - Graphics protocol, features
- **Wezterm** (Rust) - Multi-protocol support

**Libraries**:
- **libvterm** - C library for terminal emulation semantics

**Graphics Protocols**:
- Kitty graphics protocol (de facto standard for inline images)
- Sixel (legacy DEC standard)
- iTerm2 protocol

---

## Build Order with BLAZE/FLUX

Each step produces something usable:

### Phase 1: Foundation
1. **BLAZE core** - Vulkan init, swapchain, basic rendering
2. **FLUX text** - SDF font rendering, glyph atlas
3. **FLUX layout** - Basic column/row layout
4. **Terminal PTY** - Spawn shell, read/write

### Phase 2: Basic Terminal
5. **Escape parser** - ANSI sequences, SGR colors
6. **Terminal grid** - Cell storage, cursor, scrolling
7. **TermGridElement** - Custom FLUX widget for grid
8. **Input handling** - Keyboard → PTY, mouse selection

### Phase 3: Rich Terminal
9. **Scrollback** - Efficient storage, virtualized rendering
10. **Kitty graphics** - Inline images via BLAZE textures
11. **Tab support** - Multiple terminals
12. **Search overlay** - Find in scrollback

### Phase 4: Extended Features
13. **Local search/index** - Filesystem indexing
14. **LLM pipe** - `| llm` command, streaming responses
15. **Gemini browser** - Simple protocol, test browser architecture

### Phase 5: Advanced
16. **HTML subset browser** - No JS, basic CSS layout
17. **Video playback** - BLAZE + Vulkan Video
18. **Semantic search** - Embeddings, RAG integration

---

## Technical Considerations

### Scrollback Storage
- Gap buffer or rope for line data
- Content-addressed store for offloading old lines
- Index by line number for virtualization
- FLUX only generates draw calls for visible + overscan lines

### Glyph Caching (FLUX)
- Rasterize glyphs on demand to SDF
- Pack into atlas texture
- LRU eviction for large character sets
- Separate atlases for different font sizes/weights

### Performance Targets
- 60fps minimum, 120fps+ for smooth scrolling
- Sub-frame latency for input (PTY → screen)
- Efficient memory use for large scrollback (100k+ lines)
- FLUX batches all glyphs into single draw call

### FLUX Rendering Pipeline
```
┌─────────────────────────────────────────────────────────────┐
│  Frame Start                                                 │
├─────────────────────────────────────────────────────────────┤
│  1. Poll PTY for new data                                   │
│  2. Parse escape sequences → update grid                    │
│  3. Rebuild FLUX element tree (if layout changed)           │
│  4. Compute layout (if dirty)                               │
│  5. Paint → DrawList (quads, glyphs, images)                │
│  6. Upload instance buffers to GPU                          │
│  7. Single render pass:                                     │
│     - Draw all quads (backgrounds, selections, cursors)     │
│     - Draw all glyphs (text)                                │
│     - Draw inline images/video                              │
│  8. Present swapchain                                       │
├─────────────────────────────────────────────────────────────┤
│  Frame End (~1-2ms total for typical terminal content)      │
└─────────────────────────────────────────────────────────────┘
```

---

## Open Questions

- **Project name?** (RichTerm? Something else—it's more than a terminal now)
- **Gemini-first or HTML-first for browser?** (Gemini simpler, HTML more useful)
- **Local LLM vs API-based for integration?** (Ollama for local, Anthropic/OpenAI for API)
- **How does this relate to Laminae/Cortical architecture?** (Could run inside Laminae as the default terminal)
- **WASM target priority?** (Nice for embedded terminal in web apps)

---

## File Structure

```
richterm/
├── src/
│   ├── main.zig                 # Entry point
│   ├── app.zig                  # FLUX application setup
│   │
│   ├── terminal/
│   │   ├── pty.zig              # PTY management
│   │   ├── escape_parser.zig    # ANSI/xterm parser
│   │   ├── grid.zig             # Terminal cell grid
│   │   ├── scrollback.zig       # Scrollback buffer
│   │   ├── graphics.zig         # Kitty protocol
│   │   ├── video.zig            # Video playback
│   │   └── widgets/
│   │       ├── term_grid.zig    # Custom FLUX element
│   │       ├── tab_bar.zig
│   │       └── search_overlay.zig
│   │
│   ├── browser/
│   │   ├── browser.zig          # Browser state
│   │   ├── html_parser.zig      # HTML parsing
│   │   ├── css_parser.zig       # CSS parsing
│   │   ├── layout.zig           # CSS layout engine
│   │   └── gemini.zig           # Gemini protocol
│   │
│   ├── search/
│   │   ├── indexer.zig          # Filesystem indexer
│   │   ├── tokenizer.zig        # Text tokenization
│   │   └── query.zig            # Search queries
│   │
│   ├── llm/
│   │   ├── client.zig           # LLM API client
│   │   └── integration.zig      # Terminal integration
│   │
│   ├── storage/
│   │   ├── store.zig            # Content-addressed store
│   │   └── cache.zig            # LRU cache
│   │
│   └── network/
│       ├── http.zig             # HTTP client
│       └── tls.zig              # TLS (bearssl)
│
├── deps/
│   ├── blaze/                   # GPU abstraction
│   ├── flux/                    # UI framework
│   └── forge/                   # 3D rendering (future)
│
├── shaders/
│   ├── glyph.wgsl               # From FLUX
│   ├── quad.wgsl                # From FLUX
│   ├── image.wgsl               # Textured quad
│   └── video.wgsl               # Video frame display
│
└── build.zig
```

---

## Summary

The terminal project becomes a **FLUX application** that uses **BLAZE** for GPU access. This provides:

1. **Shared infrastructure** - Text rendering, layout, and GPU abstraction work across terminal, browser, search UI, and LLM chat
2. **Faster iteration** - FLUX handles UI boilerplate, you focus on terminal-specific logic
3. **Web-ready** - BLAZE's future WebGPU backend enables running in browsers
4. **Learning value** - Still deep in GPU concepts via BLAZE, but with useful abstractions

The terminal-specific work focuses on:
- PTY management
- Escape sequence parsing
- Efficient scrollback storage
- Kitty graphics protocol
- Custom `TermGridElement` widget

Everything else (text rendering, layout, input handling, GPU submission) comes from FLUX/BLAZE.
