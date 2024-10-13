const std = @import("std");

year: i64,
month: i64,
day: i64,
hour: i64,
minute: i64,
second: i64,
milli: i64,
total_milli: i64,

const Self = @This();
const one_milli = 1;
const one_second = one_milli * 1000;
const one_minute = one_second * 60;
const one_hour = one_minute * 60;
const one_day = one_hour * 24;

pub const Empty: Self = .{
    .year = 0,
    .month = 0,
    .day = 0,
    .hour = 0,
    .minute = 0,
    .second = 0,
    .milli = 0,
    .total_milli = 0,
};

pub fn IsEmpty(self: Self) bool {
    return self.total_milli == 0;
}

pub fn isLeapYear(self: Self) bool {
    return @mod(self.year, 4) == 0;
}

pub fn fromUnixMilli(unix: i64) Self {
    var rem = unix;
    var year: i64 = 1970;
    var month: i64 = 1;
    var day: i64 = 1;
    var hour: i64 = 0;
    var minute: i64 = 0;
    var second: i64 = 0;
    var milli: i64 = 0;

    var year_len: i64 = one_day * 365;
    var months_length = [_]u5{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    while (rem > 0) {
        // Leap year
        if (@mod(year, 4) == 0) {
            months_length[1] = 29;
            year_len = one_day * 366;
        } else {
            months_length[1] = 28;
            year_len = one_day * 365;
        }
        // +1 Full year
        if (rem > year_len) {
            rem -= year_len;
            year += 1;
            continue;
        }

        for (months_length, 0..) |month_len, i| {
            const days: i64 = @intFromFloat(std.math.ceil(@as(f64, @floatFromInt(rem)) / one_day));
            if (days > month_len) {
                rem -= @as(i64, month_len) * one_day;
                continue;
            }

            month = @intCast(i + 1);
            day = days;

            hour = @divFloor(@mod(rem, one_day), one_hour);
            rem -= one_hour * hour;

            minute = @divFloor(@mod(rem, one_hour), one_minute);
            rem -= one_minute * minute;

            second = @divFloor(@mod(rem, one_minute), one_second);
            rem -= one_second * second;

            milli = @divFloor(@mod(rem, one_second), one_milli);
            rem = 0;
            break;
        }
    }

    return .{
        .year = year,
        .month = month,
        .day = day,
        .hour = hour,
        .minute = minute,
        .second = second,
        .milli = milli,
        .total_milli = unix,
    };
}
