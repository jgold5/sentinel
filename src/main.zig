const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

pub fn main() !void {
    const in = try posix.inotify_init1(0);
    std.debug.print("woke up {d}\n", .{in});
    _ = try posix.inotify_add_watch(in, "/home/justin/Programming/sentinel/temp.txt", linux.IN.MODIFY);
    var fds = [_]posix.pollfd{
        .{ .fd = in, .events = posix.POLL.IN, .revents = 0 },
    };
    const flags = [_]struct { flag: u32, name: []const u8 }{ .{ .flag = linux.IN.ACCESS, .name = "ACCESS" }, .{ .flag = linux.IN.MODIFY, .name = "MODIFY" }, .{ .flag = linux.IN.CLOSE_WRITE, .name = "CLOSE_WRITE" } };
    _ = try posix.poll(&fds, -1);
    var buf: [1024]u8 = undefined;
    const bytes_read = try posix.read(fds[0].fd, buf[0..]);
    var i: usize = 0;
    while (i < bytes_read) {
        const raw = &buf[i];
        const ev: *const linux.inotify_event = @ptrCast(@alignCast(raw));
        for (flags) |f| {
            std.debug.print("{h} {h}\n", .{ ev.mask, f.flag });
            if (ev.mask & f.flag != 0) {
                std.debug.print("mask used: {s}\n", .{f.name});
            }
        }
        std.debug.print("{any}\n", .{@TypeOf(ev)});
        std.debug.print("wd {d}\n", .{ev.wd});
        std.debug.print("mask {b}\n", .{ev.mask});
        std.debug.print("cookie {d}\n", .{ev.cookie});
        std.debug.print("len {d}\n", .{ev.len});
        i += @sizeOf(linux.inotify_event) + ev.len;
    }
}
