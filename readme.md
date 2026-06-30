# arg-parse

A basic comptime cli arg parser generator.

Most of my things need only basic cli arg parsing. I want to throw an `Options` struct in and conveniently get my args out.

Auto generated help is a nice bonus.

```zig
const Options = struct {
    path: []const u8 = "./points.dat",
    limit: u32 = 16,
    verbose: bool = false,
    glyph: enum { square, circle, triangle, cross } = .square,
};
```
```sh
./zig-out/bin/prog --path ./res/long.dat --limit 512 --verbose --glyph cross
```
