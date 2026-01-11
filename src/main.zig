const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

pub fn main() !void {
    const in = try posix.inotify_init1(0);
    const fp = "/home/justin/Programming/sentinel/temp";
    const flags_to_watch = linux.IN.OPEN | linux.IN.CREATE | linux.IN.MODIFY | linux.IN.ATTRIB | linux.IN.DELETE | linux.IN.Q_OVERFLOW;
    const wd = try posix.inotify_add_watch(in, fp, flags_to_watch);
    var fds = [_]posix.pollfd{
        .{ .fd = in, .events = posix.POLL.IN, .revents = 0 },
    };
    const parent = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(parent);
    defer arena.deinit();
    const allocator = arena.allocator();
    var watch_descriptors = std.AutoHashMap(i32, []const u8).init(allocator);
    defer watch_descriptors.deinit();
    var events = std.ArrayList(Event).init(allocator);
    try watch_descriptors.put(wd, fp);
    _ = try posix.poll(&fds, -1);
    var buf: [1024]u8 = undefined;
    var count: usize = 0;
    var new_wd: i32 = 0;
    var joined: ?[]const u8 = undefined;
    var bytes_read: usize = 0;
    while (true) {
        bytes_read = try posix.read(fds[0].fd, buf[0..]);
        var i: usize = 0;
        while (i < bytes_read) {
            const raw = &buf[i];
            const ev: *const linux.inotify_event = @ptrCast(@alignCast(raw));
            const kind = EventKind.fromMask(ev.mask).?;
            if (kind == EventKind.open) {} else {
                std.debug.print("---------- COUNT {d}----------\n", .{count});
                const base = watch_descriptors.get(ev.wd).?;
                if ((kind == EventKind.create) and (ev.mask & linux.IN.ISDIR != 0)) {
                    new_wd = try posix.inotify_add_watch(in, joined.?, flags_to_watch);
                    try watch_descriptors.put(new_wd, joined.?);
                    std.debug.print("\tDIR made {s}\n", .{joined.?});
                } else {
                    const file_name = ev.getName().?;
                    joined = try std.fs.path.join(allocator, &.{ base, file_name });
                    const to_add = Event{ .kind = kind, .abs_path = joined.? };
                    try events.append(to_add);
                    std.debug.print("\tEvent received of type {any} for file {s}\n", .{ to_add.kind, to_add.abs_path });
                }
                count += 1;
            }
            i += @sizeOf(linux.inotify_event) + ev.len;
        }
    }
    for (events) |ev| {
        ev.deinit(allocator);
    }
}

const EventKind = enum(u32) {
    overflow = linux.IN.Q_OVERFLOW,
    delete = linux.IN.DELETE,
    create = linux.IN.CREATE,
    modify = linux.IN.MODIFY,
    attrib = linux.IN.ATTRIB,
    open = linux.IN.OPEN,

    fn fromMask(mask: u32) ?EventKind {
        if (mask & @intFromEnum(EventKind.overflow) != 0) {
            return EventKind.overflow;
        }
        if (mask & @intFromEnum(EventKind.delete) != 0) {
            return EventKind.delete;
        }
        if (mask & @intFromEnum(EventKind.create) != 0) {
            return EventKind.create;
        }
        if (mask & @intFromEnum(EventKind.modify) != 0) {
            return EventKind.modify;
        }
        if (mask & @intFromEnum(EventKind.attrib) != 0) {
            return EventKind.attrib;
        }
        if (mask & @intFromEnum(EventKind.open) != 0) {
            return EventKind.open;
        }
        return null;
    }
};

const Event = struct {
    kind: EventKind,
    abs_path: []const u8,

    fn deinit(self: *Event, allocator: std.mem.Allocator) void {
        allocator.free(self.abs_path);
    }
};
