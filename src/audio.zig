const std = @import("std");

const c = @cImport({
    @cInclude("miniaudio.h");
});

const engine = @import("engine.zig");

pub const Audio = struct {
    engine: c.ma_engine,
    music: c.ma_sound,

    pub fn deinit(self: *Audio) void {
        c.ma_sound_uninit(&self.music);
        c.ma_engine_uninit(&self.engine);
    }
};

pub const Plugin = struct {
    pub fn buildPlugin(self: Plugin, game: *engine.Game) !void {
        _ = self;

        try game.world.addResource(Audio{
            .engine = undefined,
            .music = undefined,
        });

        const audio = game.world.resourcePtr(Audio);

        var result: c.ma_result = undefined;

        result = c.ma_engine_init(null, &audio.engine);

        if (result != c.MA_SUCCESS) {
            return std.log.err("Failed to initialize miniaudio engine", .{});
        }

        result = c.ma_sound_init_from_file(
            &audio.engine,
            "Clair-de-lune-piano.flac",
            c.MA_SOUND_FLAG_STREAM,
            null,
            null,
            &audio.music,
        );

        if (result != c.MA_SUCCESS) {
            return std.log.err("Failed to load music file", .{});
        }

        c.ma_sound_set_looping(&audio.music, c.MA_TRUE);

        result = c.ma_sound_start(&audio.music);

        if (result != c.MA_SUCCESS) {
            return std.log.err("Failed to start music", .{});
        }
    }
};
