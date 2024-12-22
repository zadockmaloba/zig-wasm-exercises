const std = @import("std");
const rand = std.crypto.random;
const wasm_allocator = std.heap.wasm_allocator;

const BOARD_COLOR = 0x2E2E2EFF; // Jet Black
const SNAKE_COLOR = 0x81D4FAFF; // Light Blue Pastel
const FOOD_COLOR = 0xFFCDD2FF; // Soft Coral

const screen_width: comptime_int = 800;
const screen_height: comptime_int = 450;

const _cols: comptime_int = screen_width / 10;
const _rows: comptime_int = screen_height / 10;

var gb: GameBoard = undefined;

const Vector2 = struct {
    x: i16,
    y: i16,
};

const Snake = struct {
    size: u16 = 3,
    segments: [1024]Vector2 = .{.{ .x = 0, .y = 0 }} ** 1024,
    pos: Vector2,
    bounds: Vector2,

    pub fn init(pos: Vector2, bounds: Vector2) Snake {
        return .{
            .pos = pos,
            .bounds = bounds,
        };
    }

    pub fn move(self: *Snake, delta: Vector2) void {
        self.pos.x += delta.x;
        self.pos.y += delta.y;

        if (self.pos.x >= self.bounds.x) {
            self.pos.x = 0;
        } else if (self.pos.x < 0) {
            self.pos.x = self.bounds.x - 1;
        }

        if (self.pos.y >= self.bounds.y) {
            self.pos.y = 0;
        } else if (self.pos.y < 0) {
            self.pos.y = self.bounds.y - 1;
        }
        //std.debug.print("x: {}, y:{}\n", .{ self.pos.x, self.pos.y });
        self.shift();
    }

    fn shift(self: *Snake) void {
        var i = self.size - 1;
        while (i > 0) : (i -= 1) {
            self.segments[i] = self.segments[i - 1];
        }
        self.segments[0] = self.pos;
    }
};

const Rect = struct {
    pos: Vector2,
    size: Vector2 = .{ .x = 8, .y = 8 },
    color: u32,
};

const PlayerDirection = enum(u8) {
    LEFT,
    RIGHT,
    TOP,
    BOTTOM,
};

const GameBoard = struct {
    height: u16 = 400,
    width: u16 = 400,
    cols: u16 = 0,
    rows: u16 = 0,
    rect_buffer: [_cols * _rows]Rect,
    player: Snake,
    player_direction: PlayerDirection,
    food: Rect,

    pub fn init(width: u16, height: u16) GameBoard {
        return .{
            .height = height,
            .width = width,
            .cols = _cols,
            .rows = _rows,
            .player = Snake.init(.{ .x = 10, .y = 10 }, .{ .x = @as(i16, @intCast(_cols)), .y = @as(i16, @intCast(_rows)) }),
            .player_direction = .RIGHT,
            .rect_buffer = [_]Rect{
                .{
                    .pos = .{ .x = 0, .y = 0 },
                    .color = 0x000000FF,
                },
            } ** (_cols * _rows),
            .food = .{
                .pos = .{
                    .x = @as(i16, @intCast(rand.intRangeAtMost(u16, 0, _cols - 1))),
                    .y = @as(i16, @intCast(rand.intRangeAtMost(u16, 0, _rows - 1))),
                },
                .color = FOOD_COLOR,
            },
        };
    }

    pub fn deinit(self: *GameBoard) void {
        _ = self;
    }

    pub fn predraw(self: *GameBoard) void {
        for (0..self.rows) |i| for (0..self.cols) |j| {
            self.rect_buffer[(i * self.cols) + j] = .{
                .size = .{ .x = 8, .y = 8 },
                .pos = .{ .x = @as(i16, @intCast(j)), .y = @as(i16, @intCast(i)) },
                .color = BOARD_COLOR,
            };
        };
        std.debug.assert(self.rect_buffer.len > 0);
    }

    pub fn draw(self: *GameBoard) void {
        //Draw food
        const food_coord: u16 = (@as(u16, @intCast(self.food.pos.y)) * self.cols) + @as(u16, @intCast(self.food.pos.x));
        self.rect_buffer[food_coord].color = FOOD_COLOR;

        //Draw player
        for (self.player.segments[0..self.player.size], 0..) |seg, n| {
            const flat_coord: u16 = (@as(u16, @intCast(seg.y)) * self.cols) + @as(u16, @intCast(seg.x));
            std.debug.assert(flat_coord < self.rect_buffer.len);
            self.rect_buffer[flat_coord].color = SNAKE_COLOR;

            if (n > 0 and self.player.segments[0].x == seg.x and self.player.segments[0].y == seg.y) {
                self.player.size = 3;
            }
            std.debug.print("Segment: {}, pos: {any}\n", .{ n, seg });
        }

        //Draw board
        for (&self.rect_buffer) |*rect| {
            drawRectangle(
                @as(u32, @intCast(rect.pos.x * 10)),
                @as(u32, @intCast(rect.pos.y * 10)),
                @as(u32, @intCast(rect.size.x)),
                @as(u32, @intCast(rect.size.y)),
                rect.color,
            );
            rect.color = BOARD_COLOR;
        }
    }
};

pub fn main() void {
    gb = GameBoard.init(screen_width, screen_height);

    gb.predraw();

    gb.draw();

    //requestAnimationFrame(gameLoop);
}

pub fn gameLoop() void {
    //ray.beginDrawing();
    //defer ray.endDrawing();

    gb.draw();

    //std.debug.assert(gb.rect_buffer.len == 0);

    switch (gb.player_direction) {
        .RIGHT => gb.player.move(.{ .x = 1, .y = 0 }),
        .LEFT => gb.player.move(.{ .x = -1, .y = 0 }),
        .TOP => gb.player.move(.{ .x = 0, .y = -1 }),
        .BOTTOM => gb.player.move(.{ .x = 0, .y = 1 }),
    }

    //ray.clearBackground(ray.getColor(0x000000FF));
    //clearBackground(0x000000FF);

    //pollKeyEvents(&gb);
    pollPlayerEvents(&gb);
    //std.time.sleep(1_000_000_000_000);

    //requestAnimationFrame(gameLoop);
}

// fn pollKeyEvents(board: *GameBoard) void {
//     const ky = ray.getKeyPressed();
//     switch (ky) {
//         .key_left => board.player_direction = .LEFT,
//         .key_right => board.player_direction = .RIGHT,
//         .key_up => board.player_direction = .TOP,
//         .key_down => board.player_direction = .BOTTOM,
//         else => {},
//     }
// }

fn pollPlayerEvents(board: *GameBoard) void {
    if (board.player.pos.x == board.food.pos.x and board.player.pos.y == board.food.pos.y) {
        board.player.size += 1;
        board.food.pos = .{
            .x = @as(i16, @intCast(rand.intRangeAtMost(u16, 0, board.cols - 1))),
            .y = @as(i16, @intCast(rand.intRangeAtMost(u16, 0, board.rows - 1))),
        };
    }
}

extern "env" fn drawRectangle(xpos: u32, ypos: u32, xsize: u32, ysize: u32, color: u32) void;
extern "env" fn clearBackground(color: u32) void;
extern "env" fn requestAnimationFrame(callback: *const anyopaque) void;
