# Helper video fixture

`helper.webm` is a generated, silent, one-second red video (32 x 32, VP8).
It tests browser playback without camera permissions, external media, or
runtime encoding dependencies. Regenerate it with:

```sh
ffmpeg -f lavfi -i color=c=red:s=32x32:r=10:d=1 -an -c:v libvpx -b:v 20k -threads 1 helper.webm
```

The `golden_chrome` test platform allows autoplay so playback tests run without
user interaction. Camera tests substitute a stream captured from this fixture;
they never request camera permission or access a physical device.
