#include "rlottie_capi.h"
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <vector>

// MARK: - Render Lottie frames as BGRA raw video for FFmpeg
int main(int argc, char **argv) {
    if (argc != 4) {
        std::fprintf(stderr, "usage: mimi-rlottie-render input.json output.bgra fps\n");
        return 2;
    }
    const int fps = std::atoi(argv[3]);
    if (fps < 1 || fps > 60) return 2;
    Lottie_Animation *animation = lottie_animation_from_file(argv[1]);
    if (!animation) {
        std::fprintf(stderr, "rlottie could not load Lottie JSON\n");
        return 3;
    }
    size_t width = 0, height = 0;
    lottie_animation_get_size(animation, &width, &height);
    const size_t total = lottie_animation_get_totalframe(animation);
    const double sourceFPS = lottie_animation_get_framerate(animation);
    const double duration = lottie_animation_get_duration(animation);
    if (width == 0 || height == 0 || total == 0 || sourceFPS <= 0 || duration <= 0 || duration > 120) {
        lottie_animation_destroy(animation);
        std::fprintf(stderr, "invalid or excessively long Lottie animation\n");
        return 3;
    }
    constexpr size_t side = 512;
    std::vector<uint32_t> pixels(side * side);
    FILE *output = std::fopen(argv[2], "wb");
    if (!output) {
        lottie_animation_destroy(animation);
        return 4;
    }
    const size_t frames = static_cast<size_t>(std::ceil(duration * fps));
    bool success = true;
    for (size_t index = 0; index < frames; ++index) {
        const size_t sourceFrame = std::min(total - 1, static_cast<size_t>(index * sourceFPS / fps));
        std::fill(pixels.begin(), pixels.end(), 0);
        lottie_animation_render(animation, sourceFrame, pixels.data(), side, side, side * 4);
        if (std::fwrite(pixels.data(), sizeof(uint32_t), pixels.size(), output) != pixels.size()) {
            success = false;
            break;
        }
    }
    if (std::fclose(output) != 0) success = false;
    lottie_animation_destroy(animation);
    return success ? 0 : 4;
}
