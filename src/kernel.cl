

float sq(const float x) { return x * x; }

float cb(const float x) { return x * x * x; }

float angle(const float3 v1, const float3 v2) {
  return acos(dot(v1, v2) / (length(v1) * length(v2)));
}

float fast_rsqrt(const float x) {
  return as_float(0x5F37642F - (as_int(x) >> 1));
}

float fast_asin(const float x) { return x * fma(0.5702f, sq(sq(sq(x))), 1.0f); }

float fast_acos(const float x) {
  return fma(fma(-0.5702f, sq(sq(sq(x))), -1.0f), x, 1.5712963f);
}

void swap(float *x, float *y) {
  const float t = *x;
  *x = *y;
  *y = t;
}

void lu_solve(float *M, float *x, float *b, const int N, const int Nsol) {
  for (int i = 0; i < Nsol; i++) {
    for (int j = i + 1; j < Nsol; j++) {
      M[N * j + i] /= M[N * i + i];
      for (int k = i + 1; k < Nsol; k++)
        M[N * j + k] -= M[N * j + i] * M[N * i + k];
    }
  }
  for (int i = 0; i < Nsol; i++) {
    x[i] = b[i];
    for (int k = 0; k < i; k++)
      x[i] -= M[N * i + k] * x[k];
  }
  for (int i = Nsol - 1; i >= 0; i--) {
    for (int k = i + 1; k < Nsol; k++)
      x[i] -= M[N * i + k] * x[k];
    x[i] /= M[N * i + i];
  }
}

float trilinear(const float3 p, const float *v) {
  const float x1 = p.x, y1 = p.y, z1 = p.z, x0 = 1.0f - x1, y0 = 1.0f - y1,
              z0 = 1.0f - z1;
  return (x0 * y0 * z0) * v[0] + (x1 * y0 * z0) * v[1] + (x1 * y0 * z1) * v[2] +
         (x0 * y0 * z1) * v[3] + (x0 * y1 * z0) * v[4] + (x1 * y1 * z0) * v[5] +
         (x1 * y1 * z1) * v[6] + (x0 * y1 * z1) * v[7];
}

float3 trilinear3(const float3 p, const float3 *v) {
  const float x1 = p.x, y1 = p.y, z1 = p.z, x0 = 1.0f - x1, y0 = 1.0f - y1,
              z0 = 1.0f - z1;
  return (x0 * y0 * z0) * v[0] + (x1 * y0 * z0) * v[1] + (x1 * y0 * z1) * v[2] +
         (x0 * y0 * z1) * v[3] + (x0 * y1 * z0) * v[4] + (x1 * y1 * z0) * v[5] +
         (x1 * y1 * z1) * v[6] + (x0 * y1 * z1) * v[7];
}
#ifdef GRAPHICS

int color_from_floats(const float red, const float green, const float blue) {
  return clamp((int)fma(255.0f, red, 0.5f), 0, 255) << 16 |
         clamp((int)fma(255.0f, green, 0.5f), 0, 255) << 8 |
         clamp((int)fma(255.0f, blue, 0.5f), 0, 255);
}

int color_mul(const int c, const float x) {
  const int r = min((int)fma((float)((c >> 16) & 255), x, 0.5f), 255);
  const int g = min((int)fma((float)((c >> 8) & 255), x, 0.5f), 255);
  const int b = min((int)fma((float)(c & 255), x, 0.5f), 255);
  return r << 16 | g << 8 | b;
}

int color_average(const int c1, const int c2) {
  const uchar4 cc1 = as_uchar4(c1), cc2 = as_uchar4(c2);
  return as_int((uchar4)((uchar)((cc1.x + cc2.x) / 2u),
                         (uchar)((cc1.y + cc2.y) / 2u),
                         (uchar)((cc1.z + cc2.z) / 2u), (uchar)0u));
}

int color_mix(const int c1, const int c2, const float w) {
  const uchar4 cc1 = as_uchar4(c1), cc2 = as_uchar4(c2);
  const float3 fc1 = (float3)((float)cc1.x, (float)cc1.y, (float)cc1.z),
               fc2 = (float3)((float)cc2.x, (float)cc2.y, (float)cc2.z);
  const float3 fcm =
      fma(w, fc1, fma(1.0f - w, fc2, (float3)(0.5f, 0.5f, 0.5f)));
  return as_int((uchar4)((uchar)fcm.x, (uchar)fcm.y, (uchar)fcm.z, (uchar)0u));
}

int color_mix_3(const int c0, const int c1, const int c2, const float w0,
                const float w1, const float w2) {
  const uchar4 cc0 = as_uchar4(c0), cc1 = as_uchar4(c1), cc2 = as_uchar4(c2);
  const float3 fc0 = (float3)((float)cc0.x, (float)cc0.y, (float)cc0.z),
               fc1 = (float3)((float)cc1.x, (float)cc1.y, (float)cc1.z),
               fc2 = (float3)((float)cc2.x, (float)cc2.y, (float)cc2.z);
  const float3 fcm =
      fma(w0, fc0, fma(w1, fc1, fma(w2, fc2, (float3)(0.5f, 0.5f, 0.5f))));
  return as_int((uchar4)((uchar)fcm.x, (uchar)fcm.y, (uchar)fcm.z, (uchar)0u));
}

int hsv_to_rgb(const float h, const float s, const float v) {
  const float c = v * s;
  const float x = c * (1.0f - fabs(fmod(h / 60.0f, 2.0f) - 1.0f));
  const float m = v - c;
  float r = 0.0f, g = 0.0f, b = 0.0f;
  if (0.0f <= h && h < 60.0f) {
    r = c;
    g = x;
  } else if (h < 120.0f) {
    r = x;
    g = c;
  } else if (h < 180.0f) {
    g = c;
    b = x;
  } else if (h < 240.0f) {
    g = x;
    b = c;
  } else if (h < 300.0f) {
    r = x;
    b = c;
  } else if (h < 360.0f) {
    r = c;
    b = x;
  }
  return color_from_floats(r + m, g + m, b + m);
}

int colorscale_rainbow(float x) {
  x = clamp(6.0f * (1.0f - x), 0.0f, 6.0f);
  float r = 0.0f, g = 0.0f, b = 0.0f;
  if (x < 1.2f) {
    r = 1.0f;
    g = x * 0.83333333f;
  } else if (x >= 1.2f && x < 2.0f) {
    r = 2.5f - x * 1.25f;
    g = 1.0f;
  } else if (x >= 2.0f && x < 3.0f) {
    g = 1.0f;
    b = x - 2.0f;
  } else if (x >= 3.0f && x < 4.0f) {
    g = 4.0f - x;
    b = 1.0f;
  } else if (x >= 4.0f && x < 5.0f) {
    r = x * 0.4f - 1.6f;
    b = 3.0f - x * 0.5f;
  } else {
    r = 2.4f - x * 0.4f;
    b = 3.0f - x * 0.5f;
  }
  return color_from_floats(r, g, b);
}

int colorscale_iron(float x) {
  x = clamp(4.0f * (1.0f - x), 0.0f, 4.0f);
  float r = 1.0f, g = 0.0f, b = 0.0f;
  if (x < 0.66666667f) {
    g = 1.0f;
    b = 1.0f - x * 1.5f;
  } else if (x < 2.0f) {
    g = 1.5f - x * 0.75f;
  } else if (x < 3.0f) {
    r = 2.0f - x * 0.5f;
    b = x - 2.0f;
  } else {
    r = 2.0f - x * 0.5f;
    b = 4.0f - x;
  }
  return color_from_floats(r, g, b);
}

int colorscale_twocolor(float x) {
  return x > 0.5f ? color_mix(0xFFAA00, def_background_color,
                              clamp(2.0f * x - 1.0f, 0.0f, 1.0f))
                  : color_mix(def_background_color, 0x0080FF,
                              clamp(2.0f * x, 0.0f, 1.0f));
}

int shading(const int c, const float3 p, const float3 normal,
            const float *camera_cache) {
#ifndef GRAPHICS_TRANSPARENCY
  const float zoom = camera_cache[0];
  const float dis = camera_cache[1];
  const float3 pos =
      (float3)(camera_cache[2], camera_cache[3], camera_cache[4]) -
      (float3)(def_domain_offset_x, def_domain_offset_y, def_domain_offset_z);
  const float3 Rz =
      (float3)(camera_cache[11], camera_cache[12], camera_cache[13]);
  const float3 d = p - Rz * (dis / zoom) - pos;
  const float nl2 = sq(normal.x) + sq(normal.y) + sq(normal.z);
  const float dl2 = sq(d.x) + sq(d.y) + sq(d.z);
  return color_mul(c,
                   max(1.5f * fabs(dot(normal, d)) * rsqrt(nl2 * dl2), 0.3f));
#else
  return c;
#endif
}

bool is_off_screen(const int x, const int y, const int stereo) {
  switch (stereo) {
  default:
    return x < 0 || x >= def_screen_width || y < 0 || y >= def_screen_height;
  case -1:
    return x < 0 || x >= def_screen_width / 2 || y < 0 ||
           y >= def_screen_height;
  case +1:
    return x < def_screen_width / 2 || x >= def_screen_width || y < 0 ||
           y >= def_screen_height;
  }
}

void draw(const int x, const int y, const float z, const int color,
          global int *bitmap, volatile global int *zbuffer, const int stereo) {
  const int index = x + y * def_screen_width, iz = (int)(z * 1E3f);
#ifndef GRAPHICS_TRANSPARENCY
  if (!is_off_screen(x, y, stereo) && iz > atomic_max(&zbuffer[index], iz))
    bitmap[index] = color;
#else
  if (!is_off_screen(x, y, stereo)) {
    const float transparency = GRAPHICS_TRANSPARENCY;
    const uchar4 cc4 = as_uchar4(color), cb4 = as_uchar4(def_background_color);
    const float3 fc = (float3)((float)cc4.x, (float)cc4.y, (float)cc4.z);
    const float3 fb = (float3)((float)cb4.x, (float)cb4.y, (float)cb4.z);
    const bool is_front = iz > atomic_max(&zbuffer[index], iz);
    const uchar4 cp4 = as_uchar4(bitmap[index]);
    const float3 fp = (float3)((float)cp4.x, (float)cp4.y, (float)cp4.z);
    const int draw_count = (int)cp4.w;
    const float3 fn =
        fp +
        (1.0f - transparency) *
            (is_front ? fc - fp : pown(transparency, draw_count) * (fc - fb));
    bitmap[index] = as_int((uchar4)((uchar)clamp(fn.x + 0.5f, 0.0f, 255.0f),
                                    (uchar)clamp(fn.y + 0.5f, 0.0f, 255.0f),
                                    (uchar)clamp(fn.z + 0.5f, 0.0f, 255.0f),
                                    (uchar)min(draw_count + 1, 255)));
  }
#endif
}

bool convert(int *rx, int *ry, float *rz, const float3 p,
             const float *camera_cache, const int stereo) {
  const float zoom = camera_cache[0];
  const float dis = camera_cache[1];
  const float3 pos =
      (float3)(camera_cache[2], camera_cache[3], camera_cache[4]) -
      (float3)(def_domain_offset_x, def_domain_offset_y, def_domain_offset_z);
  const float3 Rx = (float3)(camera_cache[5], camera_cache[6], camera_cache[7]);
  const float3 Ry =
      (float3)(camera_cache[8], camera_cache[9], camera_cache[10]);
  const float3 Rz =
      (float3)(camera_cache[11], camera_cache[12], camera_cache[13]);
  const float eye_distance = vload_half(28, (half *)camera_cache);
  float3 t, r;
  t = p - pos -
      ((float)stereo * eye_distance / zoom) * (float3)(Rx.x, Rx.y, 0.0f);
  r.z = dot(Rz, t);
  const float rs = zoom * dis / (dis - r.z * zoom);
  if (rs <= 0.0f)
    return false;
  const float tv =
      ((as_int(camera_cache[14]) >> 30) & 0x1) && stereo != 0 ? 0.5f : 1.0f;
  r.x = (dot(Rx, t) * rs + (float)stereo * eye_distance) * tv +
        (0.5f + (float)stereo * 0.25f) * (float)def_screen_width;
  r.y = dot(Ry, t) * rs + 0.5f * (float)def_screen_height;
  *rx = (int)(r.x + 0.5f);
  *ry = (int)(r.y + 0.5f);
  *rz = r.z;
  return true;
}

void convert_circle(float3 p, const float r, const int color,
                    const float *camera_cache, global int *bitmap,
                    global int *zbuffer, const int stereo) {
  int rx, ry;
  float rz;
  if (convert(&rx, &ry, &rz, p, camera_cache, stereo)) {
    const float zoom = camera_cache[0];
    const float dis = camera_cache[1];
    const float rs = zoom * dis / (dis - rz * zoom);
    const int radius = (int)(rs * r + 0.5f);
    switch (stereo) {
    default:
      if (rx < -radius || rx >= (int)def_screen_width + radius ||
          ry < -radius || ry >= (int)def_screen_height + radius)
        return;
      break;
    case -1:
      if (rx < -radius || rx >= (int)def_screen_width / 2 + radius ||
          ry < -radius || ry >= (int)def_screen_height + radius)
        return;
      break;
    case +1:
      if (rx < (int)def_screen_width / 2 - radius ||
          rx >= (int)def_screen_width + radius || ry < -radius ||
          ry >= (int)def_screen_height + radius)
        return;
      break;
    }
    int d = -radius, x = radius, y = 0;
    while (x >= y) {
      draw(rx + x, ry + y, rz, color, bitmap, zbuffer, stereo);
      draw(rx - x, ry + y, rz, color, bitmap, zbuffer, stereo);
      draw(rx + x, ry - y, rz, color, bitmap, zbuffer, stereo);
      draw(rx - x, ry - y, rz, color, bitmap, zbuffer, stereo);
      draw(rx + y, ry + x, rz, color, bitmap, zbuffer, stereo);
      draw(rx - y, ry + x, rz, color, bitmap, zbuffer, stereo);
      draw(rx + y, ry - x, rz, color, bitmap, zbuffer, stereo);
      draw(rx - y, ry - x, rz, color, bitmap, zbuffer, stereo);
      d += 2 * y + 1;
      y++;
      if (d > 0)
        d -= 2 * (--x);
    }
  }
}

void convert_line(const float3 p0, const float3 p1, const int color,
                  const float *camera_cache, global int *bitmap,
                  global int *zbuffer, const int stereo) {
  int r0x, r0y, r1x, r1y;
  float r0z, r1z;
  if (convert(&r0x, &r0y, &r0z, p0, camera_cache, stereo) &&
      convert(&r1x, &r1y, &r1z, p1, camera_cache, stereo) &&
      !(is_off_screen(r0x, r0y, stereo) && is_off_screen(r1x, r1y, stereo))) {
    int x = r0x, y = r0y;
    const float z = 0.5f * (r0z + r1z);
    const int dx = abs(r1x - r0x), sx = 2 * (r0x < r1x) - 1;
    const int dy = -abs(r1y - r0y), sy = 2 * (r0y < r1y) - 1;
    int err = dx + dy;
    while (x != r1x || y != r1y) {
      draw(x, y, z, color, bitmap, zbuffer, stereo);
      const int e2 = 2 * err;
      if (e2 > dy) {
        err += dy;
        x += sx;
      }
      if (e2 < dx) {
        err += dx;
        y += sy;
      }
    }
  }
}

void convert_triangle(float3 p0, float3 p1, float3 p2, const int color,
                      const float *camera_cache, global int *bitmap,
                      global int *zbuffer, const int stereo) {
  int r0x, r0y, r1x, r1y, r2x, r2y;
  float r0z, r1z, r2z;
  if (convert(&r0x, &r0y, &r0z, p0, camera_cache, stereo) &&
      convert(&r1x, &r1y, &r1z, p1, camera_cache, stereo) &&
      convert(&r2x, &r2y, &r2z, p2, camera_cache, stereo) &&
      !(is_off_screen(r0x, r0y, stereo) && is_off_screen(r1x, r1y, stereo) &&
        is_off_screen(r2x, r2y, stereo))) {
    if (r0x * (r1y - r2y) + r1x * (r2y - r0y) + r2x * (r0y - r1y) > 40000 ||
        (r0y == r1y && r0y == r2y))
      return;
    if (r0y > r1y) {
      const int xt = r0x;
      const int yt = r0y;
      r0x = r1x;
      r0y = r1y;
      r1x = xt;
      r1y = yt;
    }
    if (r0y > r2y) {
      const int xt = r0x;
      const int yt = r0y;
      r0x = r2x;
      r0y = r2y;
      r2x = xt;
      r2y = yt;
    }
    if (r1y > r2y) {
      const int xt = r1x;
      const int yt = r1y;
      r1x = r2x;
      r1y = r2y;
      r2x = xt;
      r2y = yt;
    }
    const float z = (r0z + r1z + r2z) / 3.0f;
    for (int y = r0y; y < r1y; y++) {
      const int xA = r0x + (r2x - r0x) * (y - r0y) / (r2y - r0y);
      const int xB = r0x + (r1x - r0x) * (y - r0y) / (r1y - r0y);
      for (int x = min(xA, xB); x < max(xA, xB); x++) {
        draw(x, y, z, color, bitmap, zbuffer, stereo);
      }
    }
    for (int y = r1y; y < r2y; y++) {
      const int xA = r0x + (r2x - r0x) * (y - r0y) / (r2y - r0y);
      const int xB = r1x + (r2x - r1x) * (y - r1y) / (r2y - r1y);
      for (int x = min(xA, xB); x < max(xA, xB); x++) {
        draw(x, y, z, color, bitmap, zbuffer, stereo);
      }
    }
  }
}

void convert_triangle_interpolated(float3 p0, float3 p1, float3 p2, int c0,
                                   int c1, int c2, const float *camera_cache,
                                   global int *bitmap, global int *zbuffer,
                                   const int stereo) {
  int r0x, r0y, r1x, r1y, r2x, r2y;
  float r0z, r1z, r2z;
  if (convert(&r0x, &r0y, &r0z, p0, camera_cache, stereo) &&
      convert(&r1x, &r1y, &r1z, p1, camera_cache, stereo) &&
      convert(&r2x, &r2y, &r2z, p2, camera_cache, stereo) &&
      !(is_off_screen(r0x, r0y, stereo) && is_off_screen(r1x, r1y, stereo) &&
        is_off_screen(r2x, r2y, stereo))) {
    if (r0x * (r1y - r2y) + r1x * (r2y - r0y) + r2x * (r0y - r1y) > 40000 ||
        (r0y == r1y && r0y == r2y))
      return;
    if (r0y > r1y) {
      const int xt = r0x;
      const int yt = r0y;
      r0x = r1x;
      r0y = r1y;
      r1x = xt;
      r1y = yt;
      const int ct = c0;
      c0 = c1;
      c1 = ct;
    }
    if (r0y > r2y) {
      const int xt = r0x;
      const int yt = r0y;
      r0x = r2x;
      r0y = r2y;
      r2x = xt;
      r2y = yt;
      const int ct = c0;
      c0 = c2;
      c2 = ct;
    }
    if (r1y > r2y) {
      const int xt = r1x;
      const int yt = r1y;
      r1x = r2x;
      r1y = r2y;
      r2x = xt;
      r2y = yt;
      const int ct = c1;
      c1 = c2;
      c2 = ct;
    }
    const float z = (r0z + r1z + r2z) / 3.0f;
    const float d =
        (float)((r1y - r2y) * (r0x - r2x) + (r2x - r1x) * (r0y - r2y));
    for (int y = r0y; y < r1y; y++) {
      const int xA = r0x + (r2x - r0x) * (y - r0y) / (r2y - r0y);
      const int xB = r0x + (r1x - r0x) * (y - r0y) / (r1y - r0y);
      for (int x = min(xA, xB); x < max(xA, xB); x++) {
        const float w0 =
            (float)((r1y - r2y) * (x - r2x) + (r2x - r1x) * (y - r2y)) / d;
        const float w1 =
            (float)((r2y - r0y) * (x - r2x) + (r0x - r2x) * (y - r2y)) / d;
        const float w2 = 1.0f - w0 - w1;
        const int color = color_mix_3(c0, c1, c2, w0, w1, w2);
        draw(x, y, z, color, bitmap, zbuffer, stereo);
      }
    }
    for (int y = r1y; y < r2y; y++) {
      const int xA = r0x + (r2x - r0x) * (y - r0y) / (r2y - r0y);
      const int xB = r1x + (r2x - r1x) * (y - r1y) / (r2y - r1y);
      for (int x = min(xA, xB); x < max(xA, xB); x++) {
        const float w0 =
            (float)((r1y - r2y) * (x - r2x) + (r2x - r1x) * (y - r2y)) / d;
        const float w1 =
            (float)((r2y - r0y) * (x - r2x) + (r0x - r2x) * (y - r2y)) / d;
        const float w2 = 1.0f - w0 - w1;
        const int color = color_mix_3(c0, c1, c2, w0, w1, w2);
        draw(x, y, z, color, bitmap, zbuffer, stereo);
      }
    }
  }
}

void draw_point(const float3 p, const int color, const float *camera_cache,
                global int *bitmap, global int *zbuffer) {
  const bool vr = (as_int(camera_cache[14]) >> 31) & 0x1;
  int rx, ry;
  float rz;
  if (!vr) {
    if (convert(&rx, &ry, &rz, p, camera_cache, 0))
      draw(rx, ry, rz, color, bitmap, zbuffer, 0);
  } else {
    if (convert(&rx, &ry, &rz, p, camera_cache, -1))
      draw(rx, ry, rz, color, bitmap, zbuffer, -1);
    if (convert(&rx, &ry, &rz, p, camera_cache, +1))
      draw(rx, ry, rz, color, bitmap, zbuffer, +1);
  }
}

void draw_circle(const float3 p, const float r, const int color,
                 const float *camera_cache, global int *bitmap,
                 global int *zbuffer) {
  const bool vr = (as_int(camera_cache[14]) >> 31) & 0x1;
  if (!vr) {
    convert_circle(p, r, color, camera_cache, bitmap, zbuffer, 0);
  } else {
    convert_circle(p, r, color, camera_cache, bitmap, zbuffer, -1);
    convert_circle(p, r, color, camera_cache, bitmap, zbuffer, +1);
  }
}

void draw_line(const float3 p0, const float3 p1, const int color,
               const float *camera_cache, global int *bitmap,
               global int *zbuffer) {
  const bool vr = (as_int(camera_cache[14]) >> 31) & 0x1;
  if (!vr) {
    convert_line(p0, p1, color, camera_cache, bitmap, zbuffer, 0);
  } else {
    convert_line(p0, p1, color, camera_cache, bitmap, zbuffer, -1);
    convert_line(p0, p1, color, camera_cache, bitmap, zbuffer, +1);
  }
}

void draw_triangle(const float3 p0, const float3 p1, const float3 p2,
                   const int color, const float *camera_cache,
                   global int *bitmap, global int *zbuffer) {
  const bool vr = (as_int(camera_cache[14]) >> 31) & 0x1;
  if (!vr) {
    convert_triangle(p0, p1, p2, color, camera_cache, bitmap, zbuffer, 0);
  } else {
    convert_triangle(p0, p1, p2, color, camera_cache, bitmap, zbuffer, -1);
    convert_triangle(p0, p1, p2, color, camera_cache, bitmap, zbuffer, +1);
  }
}

__attribute__((always_inline)) void
draw_triangle_interpolated(const float3 p0, const float3 p1, const float3 p2,
                           const int c0, const int c1, const int c2,
                           const float *camera_cache, global int *bitmap,
                           global int *zbuffer) {
  const bool vr = (as_int(camera_cache[14]) >> 31) & 0x1;
  if (!vr) {
    convert_triangle_interpolated(p0, p1, p2, c0, c1, c2, camera_cache, bitmap,
                                  zbuffer, 0);
  } else {
    convert_triangle_interpolated(p0, p1, p2, c0, c1, c2, camera_cache, bitmap,
                                  zbuffer, -1);
    convert_triangle_interpolated(p0, p1, p2, c0, c1, c2, camera_cache, bitmap,
                                  zbuffer, +1);
  }
}

kernel void graphics_clear(global int *bitmap, global int *zbuffer) {
  const uint n = get_global_id(0);
  bitmap[n] = def_background_color;
  zbuffer[n] = -2147483648;
}

constant uchar triangle_table_data[1920] = {
    255, 255, 255, 255, 255, 255, 255, 15,  56,  255, 255, 255, 255, 255, 255,
    16,  249, 255, 255, 255, 255, 255, 31,  56,  137, 241, 255, 255, 255, 255,
    33,  250, 255, 255, 255, 255, 255, 15,  56,  33,  250, 255, 255, 255, 255,
    41,  10,  146, 255, 255, 255, 255, 47,  56,  162, 168, 137, 255, 255, 255,
    179, 242, 255, 255, 255, 255, 255, 15,  43,  184, 240, 255, 255, 255, 255,
    145, 32,  179, 255, 255, 255, 255, 31,  43,  145, 155, 184, 255, 255, 255,
    163, 177, 58,  255, 255, 255, 255, 15,  26,  128, 138, 171, 255, 255, 255,
    147, 48,  155, 171, 249, 255, 255, 159, 168, 138, 251, 255, 255, 255, 255,
    116, 248, 255, 255, 255, 255, 255, 79,  3,   55,  244, 255, 255, 255, 255,
    16,  137, 116, 255, 255, 255, 255, 79,  145, 116, 113, 19,  255, 255, 255,
    33,  138, 116, 255, 255, 255, 255, 63,  116, 3,   20,  162, 255, 255, 255,
    41,  154, 32,  72,  247, 255, 255, 47,  154, 146, 39,  55,  151, 244, 255,
    72,  55,  43,  255, 255, 255, 255, 191, 116, 43,  36,  64,  255, 255, 255,
    9,   129, 116, 50,  251, 255, 255, 79,  183, 73,  155, 43,  41,  241, 255,
    163, 49,  171, 135, 244, 255, 255, 31,  171, 65,  27,  64,  183, 244, 255,
    116, 152, 176, 185, 186, 48,  255, 79,  183, 180, 153, 171, 255, 255, 255,
    89,  244, 255, 255, 255, 255, 255, 159, 69,  128, 243, 255, 255, 255, 255,
    80,  20,  5,   255, 255, 255, 255, 143, 69,  56,  53,  81,  255, 255, 255,
    33,  154, 69,  255, 255, 255, 255, 63,  128, 33,  74,  89,  255, 255, 255,
    37,  90,  36,  4,   242, 255, 255, 47,  90,  35,  53,  69,  67,  248, 255,
    89,  36,  179, 255, 255, 255, 255, 15,  43,  128, 75,  89,  255, 255, 255,
    80,  4,   81,  50,  251, 255, 255, 47,  81,  82,  40,  184, 132, 245, 255,
    58,  171, 49,  89,  244, 255, 255, 79,  89,  128, 129, 26,  184, 250, 255,
    69,  80,  176, 181, 186, 48,  255, 95,  132, 133, 170, 184, 255, 255, 255,
    121, 88,  151, 255, 255, 255, 255, 159, 3,   89,  83,  55,  255, 255, 255,
    112, 8,   113, 81,  247, 255, 255, 31,  53,  83,  247, 255, 255, 255, 255,
    121, 152, 117, 26,  242, 255, 255, 175, 33,  89,  80,  3,   117, 243, 255,
    8,   130, 82,  88,  167, 37,  255, 47,  90,  82,  51,  117, 255, 255, 255,
    151, 117, 152, 179, 242, 255, 255, 159, 117, 121, 146, 2,   114, 251, 255,
    50,  11,  129, 113, 24,  117, 255, 191, 18,  27,  119, 81,  255, 255, 255,
    89,  136, 117, 26,  163, 179, 255, 95,  7,   5,   121, 11,  1,   186, 10,
    171, 176, 48,  90,  128, 112, 117, 176, 90,  183, 245, 255, 255, 255, 255,
    106, 245, 255, 255, 255, 255, 255, 15,  56,  165, 246, 255, 255, 255, 255,
    9,   81,  106, 255, 255, 255, 255, 31,  56,  145, 88,  106, 255, 255, 255,
    97,  37,  22,  255, 255, 255, 255, 31,  86,  33,  54,  128, 255, 255, 255,
    105, 149, 96,  32,  246, 255, 255, 95,  137, 133, 82,  98,  35,  248, 255,
    50,  171, 86,  255, 255, 255, 255, 191, 128, 43,  160, 86,  255, 255, 255,
    16,  41,  179, 165, 246, 255, 255, 95,  106, 145, 146, 43,  137, 251, 255,
    54,  107, 53,  21,  243, 255, 255, 15,  184, 176, 5,   21,  181, 246, 255,
    179, 6,   99,  96,  5,   149, 255, 111, 149, 150, 187, 137, 255, 255, 255,
    165, 70,  135, 255, 255, 255, 255, 79,  3,   116, 99,  165, 255, 255, 255,
    145, 80,  106, 72,  247, 255, 255, 175, 86,  145, 23,  55,  151, 244, 255,
    22,  98,  21,  116, 248, 255, 255, 31,  82,  37,  54,  64,  67,  247, 255,
    72,  151, 80,  96,  5,   98,  255, 127, 147, 151, 52,  146, 149, 38,  150,
    179, 114, 72,  106, 245, 255, 255, 95,  106, 116, 66,  2,   114, 251, 255,
    16,  73,  135, 50,  91,  106, 255, 159, 18,  185, 146, 180, 183, 84,  106,
    72,  55,  91,  83,  81,  107, 255, 95,  177, 181, 22,  176, 183, 4,   180,
    80,  9,   86,  48,  182, 54,  72,  103, 149, 150, 75,  151, 183, 249, 255,
    74,  105, 164, 255, 255, 255, 255, 79,  106, 148, 10,  56,  255, 255, 255,
    10,  161, 6,   70,  240, 255, 255, 143, 19,  24,  134, 70,  22,  250, 255,
    65,  25,  66,  98,  244, 255, 255, 63,  128, 33,  41,  148, 98,  244, 255,
    32,  68,  98,  255, 255, 255, 255, 143, 35,  40,  68,  98,  255, 255, 255,
    74,  169, 70,  43,  243, 255, 255, 15,  40,  130, 75,  169, 164, 246, 255,
    179, 2,   97,  96,  100, 161, 255, 111, 20,  22,  74,  24,  18,  139, 27,
    105, 148, 99,  25,  179, 54,  255, 143, 27,  24,  176, 22,  25,  100, 20,
    179, 54,  6,   96,  244, 255, 255, 111, 132, 107, 248, 255, 255, 255, 255,
    167, 118, 168, 152, 250, 255, 255, 15,  55,  160, 7,   169, 118, 250, 255,
    106, 23,  122, 113, 24,  8,   255, 175, 118, 122, 17,  55,  255, 255, 255,
    33,  22,  134, 129, 137, 118, 255, 47,  150, 146, 97,  151, 144, 115, 147,
    135, 112, 96,  6,   242, 255, 255, 127, 35,  118, 242, 255, 255, 255, 255,
    50,  171, 134, 138, 137, 118, 255, 47,  112, 114, 11,  121, 118, 154, 122,
    129, 16,  135, 161, 103, 167, 50,  187, 18,  27,  167, 22,  118, 241, 255,
    152, 134, 118, 25,  182, 54,  49,  6,   25,  107, 247, 255, 255, 255, 255,
    135, 112, 96,  179, 176, 6,   255, 127, 107, 255, 255, 255, 255, 255, 255,
    103, 251, 255, 255, 255, 255, 255, 63,  128, 123, 246, 255, 255, 255, 255,
    16,  185, 103, 255, 255, 255, 255, 143, 145, 56,  177, 103, 255, 255, 255,
    26,  98,  123, 255, 255, 255, 255, 31,  162, 3,   104, 123, 255, 255, 255,
    146, 32,  154, 182, 247, 255, 255, 111, 123, 162, 163, 56,  154, 248, 255,
    39,  99,  114, 255, 255, 255, 255, 127, 128, 103, 96,  2,   255, 255, 255,
    114, 38,  115, 16,  249, 255, 255, 31,  38,  129, 22,  137, 120, 246, 255,
    122, 166, 113, 49,  247, 255, 255, 175, 103, 113, 26,  120, 1,   248, 255,
    48,  7,   167, 160, 105, 122, 255, 127, 166, 167, 136, 154, 255, 255, 255,
    134, 180, 104, 255, 255, 255, 255, 63,  182, 3,   6,   100, 255, 255, 255,
    104, 139, 100, 9,   241, 255, 255, 159, 100, 105, 147, 19,  59,  246, 255,
    134, 100, 139, 162, 241, 255, 255, 31,  162, 3,   11,  182, 64,  246, 255,
    180, 72,  182, 32,  41,  154, 255, 175, 57,  58,  146, 52,  59,  70,  54,
    40,  131, 36,  100, 242, 255, 255, 15,  36,  100, 242, 255, 255, 255, 255,
    145, 32,  67,  66,  70,  131, 255, 31,  73,  65,  34,  100, 255, 255, 255,
    24,  131, 22,  72,  102, 26,  255, 175, 1,   10,  102, 64,  255, 255, 255,
    100, 67,  131, 166, 3,   147, 154, 163, 73,  166, 244, 255, 255, 255, 255,
    148, 117, 182, 255, 255, 255, 255, 15,  56,  148, 181, 103, 255, 255, 255,
    5,   81,  4,   103, 251, 255, 255, 191, 103, 56,  52,  69,  19,  245, 255,
    89,  164, 33,  103, 251, 255, 255, 111, 123, 33,  10,  56,  148, 245, 255,
    103, 91,  164, 36,  74,  32,  255, 63,  132, 83,  52,  82,  90,  178, 103,
    39,  115, 38,  69,  249, 255, 255, 159, 69,  128, 6,   38,  134, 247, 255,
    99,  50,  103, 81,  80,  4,   255, 111, 130, 134, 39,  129, 132, 21,  133,
    89,  164, 97,  113, 22,  115, 255, 31,  166, 113, 22,  112, 120, 144, 69,
    4,   74,  90,  48,  106, 122, 115, 122, 166, 167, 88,  164, 132, 250, 255,
    150, 101, 155, 139, 249, 255, 255, 63,  182, 96,  3,   101, 144, 245, 255,
    176, 8,   181, 16,  85,  182, 255, 111, 59,  54,  85,  19,  255, 255, 255,
    33,  154, 181, 185, 184, 101, 255, 15,  59,  96,  11,  105, 101, 25,  162,
    139, 181, 101, 8,   165, 37,  32,  101, 59,  54,  37,  58,  90,  243, 255,
    133, 89,  130, 101, 50,  40,  255, 159, 101, 105, 0,   38,  255, 255, 255,
    81,  24,  8,   101, 56,  40,  38,  24,  101, 18,  246, 255, 255, 255, 255,
    49,  22,  166, 131, 86,  150, 152, 166, 1,   10,  150, 5,   101, 240, 255,
    48,  88,  166, 255, 255, 255, 255, 175, 101, 255, 255, 255, 255, 255, 255,
    91,  122, 181, 255, 255, 255, 255, 191, 165, 123, 133, 3,   255, 255, 255,
    181, 87,  186, 145, 240, 255, 255, 175, 87,  186, 151, 24,  56,  241, 255,
    27,  178, 23,  87,  241, 255, 255, 15,  56,  33,  23,  87,  39,  251, 255,
    121, 149, 114, 9,   34,  123, 255, 127, 37,  39,  91,  41,  35,  152, 40,
    82,  42,  83,  115, 245, 255, 255, 143, 2,   88,  130, 87,  42,  245, 255,
    9,   81,  58,  53,  55,  42,  255, 159, 40,  41,  129, 39,  42,  117, 37,
    49,  53,  87,  255, 255, 255, 255, 15,  120, 112, 17,  87,  255, 255, 255,
    9,   147, 83,  53,  247, 255, 255, 159, 120, 149, 247, 255, 255, 255, 255,
    133, 84,  138, 186, 248, 255, 255, 95,  64,  181, 80,  186, 59,  240, 255,
    16,  137, 164, 168, 171, 84,  255, 175, 75,  74,  181, 67,  73,  49,  65,
    82,  33,  88,  178, 72,  133, 255, 15,  180, 176, 67,  181, 178, 81,  177,
    32,  5,   149, 178, 69,  133, 139, 149, 84,  178, 243, 255, 255, 255, 255,
    82,  58,  37,  67,  53,  72,  255, 95,  42,  37,  68,  2,   255, 255, 255,
    163, 50,  165, 131, 69,  133, 16,  89,  42,  37,  20,  41,  73,  242, 255,
    72,  133, 53,  83,  241, 255, 255, 15,  84,  1,   245, 255, 255, 255, 255,
    72,  133, 53,  9,   5,   83,  255, 159, 84,  255, 255, 255, 255, 255, 255,
    180, 71,  185, 169, 251, 255, 255, 15,  56,  148, 151, 123, 169, 251, 255,
    161, 27,  75,  65,  112, 180, 255, 63,  65,  67,  24,  74,  71,  171, 75,
    180, 151, 75,  41,  155, 33,  255, 159, 71,  185, 151, 177, 178, 1,   56,
    123, 180, 36,  66,  240, 255, 255, 191, 71,  75,  130, 67,  35,  244, 255,
    146, 42,  151, 50,  119, 148, 255, 159, 122, 121, 164, 114, 120, 32,  112,
    115, 58,  42,  71,  26,  10,  4,   26,  42,  120, 244, 255, 255, 255, 255,
    148, 65,  113, 23,  243, 255, 255, 79,  25,  20,  7,   24,  120, 241, 255,
    4,   115, 52,  255, 255, 255, 255, 79,  120, 255, 255, 255, 255, 255, 255,
    169, 168, 139, 255, 255, 255, 255, 63,  144, 147, 187, 169, 255, 255, 255,
    16,  10,  138, 168, 251, 255, 255, 63,  161, 59,  250, 255, 255, 255, 255,
    33,  27,  155, 185, 248, 255, 255, 63,  144, 147, 27,  146, 178, 249, 255,
    32,  139, 176, 255, 255, 255, 255, 63,  178, 255, 255, 255, 255, 255, 255,
    50,  40,  168, 138, 249, 255, 255, 159, 42,  144, 242, 255, 255, 255, 255,
    50,  40,  168, 16,  24,  138, 255, 31,  42,  255, 255, 255, 255, 255, 255,
    49,  152, 129, 255, 255, 255, 255, 15,  25,  255, 255, 255, 255, 255, 255,
    48,  248, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255};

uchar triangle_table(const uint i) {
  return (triangle_table_data[i / 2u] >> (4u * (i % 2u))) & 0xF;
}

float interpolate(const float v1, const float v2, const float iso) {
  return (iso - v1) / (v2 - v1);
}

uint marching_cubes(const float *v, const float iso, float3 *triangles) {
  uint cube = 0u;
  for (uint i = 0u; i < 8u; i++)
    cube |= (v[i] < iso) << i;
  if (cube == 0u || cube == 255u)
    return 0u;
  float3 vertex[12];
  vertex[0] = (float3)(interpolate(v[0], v[1], iso), 0.0f, 0.0f);
  vertex[1] = (float3)(1.0f, 0.0f, interpolate(v[1], v[2], iso));
  vertex[2] = (float3)(interpolate(v[3], v[2], iso), 0.0f, 1.0f);
  vertex[3] = (float3)(0.0f, 0.0f, interpolate(v[0], v[3], iso));
  vertex[4] = (float3)(interpolate(v[4], v[5], iso), 1.0f, 0.0f);
  vertex[5] = (float3)(1.0f, 1.0f, interpolate(v[5], v[6], iso));
  vertex[6] = (float3)(interpolate(v[7], v[6], iso), 1.0f, 1.0f);
  vertex[7] = (float3)(0.0f, 1.0f, interpolate(v[4], v[7], iso));
  vertex[8] = (float3)(0.0f, interpolate(v[0], v[4], iso), 0.0f);
  vertex[9] = (float3)(1.0f, interpolate(v[1], v[5], iso), 0.0f);
  vertex[10] = (float3)(1.0f, interpolate(v[2], v[6], iso), 1.0f);
  vertex[11] = (float3)(0.0f, interpolate(v[3], v[7], iso), 1.0f);
  cube *= 15u;
  uint i;
  for (i = 0u; i < 15u && triangle_table(cube + i) != 15u; i += 3u) {
    triangles[i] = vertex[triangle_table(cube + i)];
    triangles[i + 1u] = vertex[triangle_table(cube + i + 1u)];
    triangles[i + 2u] = vertex[triangle_table(cube + i + 2u)];
  }
  return i / 3u;
}

uint marching_cubes_halfway(const bool *v, float3 *triangles) {
  uint cube = 0u;
  for (uint i = 0u; i < 8u; i++)
    cube |= (uint)(!v[i]) << i;
  if (cube == 0u || cube == 255u)
    return 0u;
  float3 vertex[12];
  vertex[0] = (float3)(0.5f, 0.0f, 0.0f);
  vertex[1] = (float3)(1.0f, 0.0f, 0.5f);
  vertex[2] = (float3)(0.5f, 0.0f, 1.0f);
  vertex[3] = (float3)(0.0f, 0.0f, 0.5f);
  vertex[4] = (float3)(0.5f, 1.0f, 0.0f);
  vertex[5] = (float3)(1.0f, 1.0f, 0.5f);
  vertex[6] = (float3)(0.5f, 1.0f, 1.0f);
  vertex[7] = (float3)(0.0f, 1.0f, 0.5f);
  vertex[8] = (float3)(0.0f, 0.5f, 0.0f);
  vertex[9] = (float3)(1.0f, 0.5f, 0.0f);
  vertex[10] = (float3)(1.0f, 0.5f, 1.0f);
  vertex[11] = (float3)(0.0f, 0.5f, 1.0f);
  cube *= 15u;
  uint i;
  for (i = 0u; i < 15u && triangle_table(cube + i) != 15u; i += 3u) {
    triangles[i] = vertex[triangle_table(cube + i)];
    triangles[i + 1u] = vertex[triangle_table(cube + i + 1u)];
    triangles[i + 2u] = vertex[triangle_table(cube + i + 2u)];
  }
  return i / 3u;
}

typedef struct __attribute__((packed)) struct_ray {
  float3 origin;
  float3 direction;
} ray;

float intersect_sphere(const ray r, const float3 center, const float radius) {
  const float3 oc = center - r.origin;
  const float b = dot(oc, r.direction), c = sq(b) - dot(oc, oc) + sq(radius);
  return c < 0.0f ? -1.0f : b - sqrt(c);
}

float intersect_sphere_inside(const ray r, const float3 center,
                              const float radius) {
  const float3 oc = center - r.origin;
  const float b = dot(oc, r.direction), c = sq(b) - dot(oc, oc) + sq(radius);
  return c < 0.0f ? -1.0f : b + sqrt(c);
}

float intersect_triangle(const ray r, const float3 p0, const float3 p1,
                         const float3 p2) {
  const float3 u = p1 - p0, v = p2 - p0, w = r.origin - p0,
               h = cross(r.direction, v), q = cross(w, u);
  const float g = dot(u, h), f = 1.0f / g, s = f * dot(w, h),
              t = f * dot(r.direction, q);
  return (g <= 0.0f || s < -0.0001f || s > 1.0001f || t < -0.0001f ||
          s + t > 1.0001f)
             ? -1.0f
             : f * dot(v, q);
}

float intersect_triangle_bidirectional(const ray r, const float3 p0,
                                       const float3 p1, const float3 p2) {
  const float3 u = p1 - p0, v = p2 - p0, w = r.origin - p0,
               h = cross(r.direction, v), q = cross(w, u);
  const float g = dot(u, h), f = 1.0f / g, s = f * dot(w, h),
              t = f * dot(r.direction, q);
  return (g == 0.0f || s < -0.0001f || s > 1.0001f || t < -0.0001f ||
          s + t > 1.0001f)
             ? -1.0f
             : f * dot(v, q);
}

float intersect_rhombus(const ray r, const float3 p0, const float3 p1,
                        const float3 p2) {
  const float3 u = p1 - p0, v = p2 - p0, w = r.origin - p0,
               h = cross(r.direction, v), q = cross(w, u);
  const float g = dot(u, h), f = 1.0f / g, s = f * dot(w, h),
              t = f * dot(r.direction, q);
  return (g <= 0.0f || s < -0.0001f || s > 1.0001f || t < -0.0001f ||
          t > 1.0001f)
             ? -1.0f
             : f * dot(v, q);
}

float intersect_plane(const ray r, const float3 p0, const float3 p1,
                      const float3 p2) {
  const float3 u = p1 - p0, v = p2 - p0, w = r.origin - p0,
               h = cross(r.direction, v);
  const float g = dot(u, h);
  return g <= 0.0f ? -1.0f : dot(v, cross(w, u)) / g;
}

float intersect_plane_bidirectional(const ray r, const float3 p0,
                                    const float3 p1, const float3 p2) {
  const float3 u = p1 - p0, v = p2 - p0, w = r.origin - p0,
               h = cross(r.direction, v);
  const float g = dot(u, h);
  return g == 0.0f ? -1.0f : dot(v, cross(w, u)) / g;
}

bool intersect_cuboid_bool(const ray r, const float3 center, const float Lx,
                           const float Ly, const float Lz) {
  const float3 bmin = center - 0.5f * (float3)(Lx, Ly, Lz);
  const float3 bmax = center + 0.5f * (float3)(Lx, Ly, Lz);
  const float txa = (bmin.x - r.origin.x) / r.direction.x;
  const float txb = (bmax.x - r.origin.x) / r.direction.x;
  const float txmin = fmin(txa, txb);
  const float txmax = fmax(txa, txb);
  const float tya = (bmin.y - r.origin.y) / r.direction.y;
  const float tyb = (bmax.y - r.origin.y) / r.direction.y;
  const float tymin = fmin(tya, tyb);
  const float tymax = fmax(tya, tyb);
  if (txmin > tymax || tymin > txmax)
    return false;
  const float tza = (bmin.z - r.origin.z) / r.direction.z;
  const float tzb = (bmax.z - r.origin.z) / r.direction.z;
  const float tzmin = fmin(tza, tzb);
  const float tzmax = fmax(tza, tzb);
  return fmax(txmin, tymin) <= tzmax && tzmin <= fmin(txmax, tymax);
}

float intersect_cuboid(const ray r, const float3 center, const float Lx,
                       const float Ly, const float Lz) {
  const float3 bmin = center - 0.5f * (float3)(Lx, Ly, Lz);
  const float3 bmax = center + 0.5f * (float3)(Lx, Ly, Lz);
  if (r.origin.x >= bmin.x && r.origin.y >= bmin.y && r.origin.z >= bmin.z &&
      r.origin.x <= bmax.x && r.origin.y <= bmax.y && r.origin.z <= bmax.z)
    return 0.0f;
  float3 p[8];
  p[0] = (float3)(bmin.x, bmin.y, bmin.z);
  p[1] = (float3)(bmax.x, bmin.y, bmin.z);
  p[2] = (float3)(bmax.x, bmin.y, bmax.z);
  p[3] = (float3)(bmin.x, bmin.y, bmax.z);
  p[4] = (float3)(bmin.x, bmax.y, bmin.z);
  p[5] = (float3)(bmax.x, bmax.y, bmin.z);
  p[6] = (float3)(bmax.x, bmax.y, bmax.z);
  p[7] = (float3)(bmin.x, bmax.y, bmax.z);
  float intersect = -1.0f;
  intersect = fmax(intersect, intersect_rhombus(r, p[0], p[3], p[4]));
  intersect = fmax(intersect, intersect_rhombus(r, p[2], p[1], p[6]));
  intersect = fmax(intersect, intersect_rhombus(r, p[1], p[2], p[0]));
  intersect = fmax(intersect, intersect_rhombus(r, p[7], p[6], p[4]));
  intersect = fmax(intersect, intersect_rhombus(r, p[1], p[0], p[5]));
  intersect = fmax(intersect, intersect_rhombus(r, p[3], p[2], p[7]));
  return intersect;
}

float intersect_cuboid_inside_with_normal(const ray r, const float3 center,
                                          const float Lx, const float Ly,
                                          const float Lz, float3 *normal) {
  const float3 bmin = center - 0.5f * (float3)(Lx, Ly, Lz);
  const float3 bmax = center + 0.5f * (float3)(Lx, Ly, Lz);
  float3 p[8];
  p[0] = (float3)(bmin.x, bmin.y, bmin.z);
  p[1] = (float3)(bmax.x, bmin.y, bmin.z);
  p[2] = (float3)(bmax.x, bmin.y, bmax.z);
  p[3] = (float3)(bmin.x, bmin.y, bmax.z);
  p[4] = (float3)(bmin.x, bmax.y, bmin.z);
  p[5] = (float3)(bmax.x, bmax.y, bmin.z);
  p[6] = (float3)(bmax.x, bmax.y, bmax.z);
  p[7] = (float3)(bmin.x, bmax.y, bmax.z);
  float intersect = -1.0f;
  float rhombus_intersect[6];
  rhombus_intersect[0] = intersect_rhombus(r, p[2], p[6], p[1]);
  rhombus_intersect[1] = intersect_rhombus(r, p[0], p[4], p[3]);
  rhombus_intersect[2] = intersect_rhombus(r, p[7], p[4], p[6]);
  rhombus_intersect[3] = intersect_rhombus(r, p[1], p[0], p[2]);
  rhombus_intersect[4] = intersect_rhombus(r, p[3], p[7], p[2]);
  rhombus_intersect[5] = intersect_rhombus(r, p[1], p[5], p[0]);
  uint side = 0u;
  for (uint i = 0u; i < 6u; i++) {
    if (rhombus_intersect[i] > intersect) {
      intersect = rhombus_intersect[i];
      side = i;
    }
  }
  *normal = (float3)(side == 0u   ? 1.0f
                     : side == 1u ? -1.0f
                                  : 0.0f,
                     side == 2u   ? 1.0f
                     : side == 3u ? -1.0f
                                  : 0.0f,
                     side == 4u   ? 1.0f
                     : side == 5u ? -1.0f
                                  : 0.0f);
  return intersect;
}

float3 reflect(const float3 direction, const float3 normal) {
  return direction - 2.0f * dot(direction, normal) * normal;
}

float3 refract(const float3 direction, const float3 normal, const float n) {
  const float direction_normal = dot(direction, normal);
  const float sqrt_part = sq(n) - 1.0f + sq(direction_normal);
  return sqrt_part >= 0.0f
             ? (direction - (direction_normal + sqrt(sqrt_part)) * normal) / n
             : direction - 2.0f * direction_normal * normal;
}

ray get_camray(const int x, const int y, const float *camera_cache) {
  const float zoom = camera_cache[0];
  const float dis = camera_cache[1];
  const float3 pos =
      (float3)(camera_cache[2], camera_cache[3], camera_cache[4]) -
      (float3)(def_domain_offset_x, def_domain_offset_y, def_domain_offset_z);
  const float3 Rx = (float3)(camera_cache[5], camera_cache[6], camera_cache[7]);
  const float3 Ry =
      (float3)(camera_cache[8], camera_cache[9], camera_cache[10]);
  const float3 Rz =
      (float3)(camera_cache[11], camera_cache[12], camera_cache[13]);
  const bool vr = (as_int(camera_cache[14]) >> 31) & 0x1;
  const float rtv = (as_int(camera_cache[14]) >> 30) & 0x1 ? 2.0f : 1.0f;
  const float eye_distance = vload_half(28, (half *)camera_cache);
  const float stereo = (x < (int)def_screen_width / 2 ? -1.0f : 1.0f);
  float3 p0 =
      (float3)(!vr ? 0.0f : stereo * eye_distance / zoom, 0.0f, dis / zoom);
  float3 p1 =
      p0 + normalize((float3)(!vr ? (float)(x - (int)def_screen_width / 2)
                                  : ((float)(x - (int)def_screen_width / 2) -
                                     stereo * (float)(def_screen_width / 4u)) *
                                            rtv -
                                        stereo * eye_distance,
                              (float)(y - (int)def_screen_height / 2), -dis));
  p0 = Rx * p0.x + Ry * p0.y + Rz * p0.z + pos;
  p1 = Rx * p1.x + Ry * p1.y + Rz * p1.z + pos;
  ray camray;
  camray.origin = p0;
  camray.direction = p1 - p0;
  return camray;
}

int skybox_bottom(const ray r, const int c1, const int c2,
                  const int skybox_color) {
  const float3 p0 = (float3)(0.0f, 0.0f, -0.5f * (float)def_Nz),
               p1 = (float3)(1.0f, 0.0f, -0.5f * (float)def_Nz),
               p2 = (float3)(0.0f, 1.0f, -0.5f * (float)def_Nz);
  const float distance = intersect_plane(r, p0, p1, p2);
  if (distance > 0.0f) {
    const float3 normal = normalize(cross(p1 - p0, p2 - p0));
    float3 intersection = r.origin + distance * r.direction;
    const float scale = 2.0f / fmin((float)def_Nx, (float)def_Ny);
    int a = abs((int)floor(scale * intersection.x));
    int b = abs((int)floor(scale * intersection.y));
    const float r = scale * sqrt(sq(intersection.x) + sq(intersection.y));
    const int w = (a % 2 == b % 2);
    return color_mix(w * c1 + (1 - w) * c2, color_mix(c1, c2, 0.5f),
                     clamp(10.0f / r, 0.0f, 1.0f));
  } else {
    return skybox_color;
  }
}

int skybox_color_bw(const float x, const float y) {
  return color_mul(0xFFFFFF, 1.0f - y);
}

int skybox_color_hsv(const float x, const float y) {
  const float h = fmod(x * 360.0f + 120.0f, 360.0f);
  const float s = y > 0.5f ? 1.0f : 2.0f * y;
  const float v = y > 0.5f ? 2.0f - 2.0f * y : 1.0f;
  return hsv_to_rgb(h, s, v);
}

int skybox_color_sunset(const float x, const float y) {
  return color_mix(255 << 16 | 175 << 8 | 55,
                   y < 0.5f ? 55 << 16 | 111 << 8 | 255 : 0,
                   2.0f * (0.5f - fabs(y - 0.5f)));
}

int skybox_color_grid(const float x, const float y, const int c1,
                      const int c2) {
  int a = (int)(72.0f * x);
  int b = (int)(36.0f * y);
  const int w = (a % 2 == b % 2);
  return w * c1 + (1 - w) * c2;
}

int skybox_color(const ray r, const global int *skybox) {
  const float3 direction = normalize(r.direction);
  const float fu =
      (float)def_skybox_width *
      fma(atan2(direction.x, direction.y), 0.5f / 3.1415927f, 0.5f);
  const float fv = (float)def_skybox_height *
                   fma(asin(direction.z), -1.0f / 3.1415927f, 0.5f);
  const int ua = clamp((int)fu, 0, (int)def_skybox_width - 1),
            va = clamp((int)fv, 0, (int)def_skybox_height - 1),
            ub = (ua + 1) % def_skybox_width,
            vb = min(va + 1, (int)def_skybox_height - 1);
  const int s00 = skybox[ua + va * def_skybox_width],
            s01 = skybox[ua + vb * def_skybox_width],
            s10 = skybox[ub + va * def_skybox_width],
            s11 = skybox[ub + vb * def_skybox_width];
  const float u1 = fu - (float)ua, v1 = fv - (float)va, u0 = 1.0f - u1,
              v0 = 1.0f - v1;
  return color_mix(color_mix(s00, s01, v0), color_mix(s10, s11, v0), u0);
}

int last_ray(const ray reflection, const ray transmission,
             const float reflectivity, const float transmissivity,
             const global int *skybox) {
  return color_mix(skybox_color(reflection, skybox),
                   color_mix(skybox_color(transmission, skybox),
                             def_absorption_color, transmissivity),
                   reflectivity);
}

float interpolate_phi(const float3 p, const global float *phi, const uint Nx,
                      const uint Ny, const uint Nz) {
  const float xa = p.x - 0.5f + 1.5f * (float)Nx,
              ya = p.y - 0.5f + 1.5f * (float)Ny,
              za = p.z - 0.5f + 1.5f * (float)Nz;
  const uint xb = (uint)xa, yb = (uint)ya, zb = (uint)za;
  const float x1 = xa - (float)xb, y1 = ya - (float)yb, z1 = za - (float)zb,
              x0 = 1.0f - x1, y0 = 1.0f - y1, z0 = 1.0f - z1;
  float phin[8];
  for (uint c = 0u; c < 8u; c++) {
    const uint i = (c & 0x04u) >> 2, j = (c & 0x02u) >> 1, k = c & 0x01u;
    const uint x = (xb + i) % Nx, y = (yb + j) % Ny, z = (zb + k) % Nz;
    const uxx n = (uxx)x + (uxx)(y + z * Ny) * (uxx)Nx;
    phin[c] = phi[n];
  }
  return (x0 * y0 * z0) * phin[0] + (x0 * y0 * z1) * phin[1] +
         (x0 * y1 * z0) * phin[2] + (x0 * y1 * z1) * phin[3] +
         (x1 * y0 * z0) * phin[4] + (x1 * y0 * z1) * phin[5] +
         (x1 * y1 * z0) * phin[6] + (x1 * y1 * z1) * phin[7];
}

float ray_grid_traverse(const ray r, const global float *phi,
                        const global uchar *flags, float3 *normal,
                        const uint Nx, const uint Ny, const uint Nz) {
  const float3 p = (float3)(r.origin.x - 0.5f + 0.5f * (float)Nx,
                            r.origin.y - 0.5f + 0.5f * (float)Ny,
                            r.origin.z - 0.5f + 0.5f * (float)Nz);
  const int dx = (int)sign(r.direction.x), dy = (int)sign(r.direction.y),
            dz = (int)sign(r.direction.z);
  int3 xyz = (int3)((int)floor(p.x), (int)floor(p.y), (int)floor(p.z));
  const float fxa = p.x - floor(p.x), fya = p.y - floor(p.y),
              fza = p.z - floor(p.z);
  const float tdx = 1.0f / fmax(fabs(r.direction.x), 1E-6f);
  const float tdy = 1.0f / fmax(fabs(r.direction.y), 1E-6f);
  const float tdz = 1.0f / fmax(fabs(r.direction.z), 1E-6f);
  float tmx = tdx * (dx > 0 ? 1.0f - fxa : dx < 0 ? fxa : 0.0f);
  float tmy = tdy * (dy > 0 ? 1.0f - fya : dy < 0 ? fya : 0.0f);
  float tmz = tdz * (dz > 0 ? 1.0f - fza : dz < 0 ? fza : 0.0f);
  for (uint tc = 0u; tc < Nx + Ny + Nz; tc++) {
    if (tmx < tmy) {
      if (tmx < tmz) {
        xyz.x += dx;
        tmx += tdx;
      } else {
        xyz.z += dz;
        tmz += tdz;
      }
    } else {
      if (tmy < tmz) {
        xyz.y += dy;
        tmy += tdy;
      } else {
        xyz.z += dz;
        tmz += tdz;
      }
    }
    if (xyz.x < -1 || xyz.y < -1 || xyz.z < -1 || xyz.x >= (int)Nx ||
        xyz.y >= (int)Ny || xyz.z >= (int)Nz)
      break;
    else if (xyz.x < 0 || xyz.y < 0 || xyz.z < 0 || xyz.x >= (int)Nx - 1 ||
             xyz.y >= (int)Ny - 1 || xyz.z >= (int)Nz - 1)
      continue;
    const uxx x0 = (uxx)xyz.x;
    const uxx xp = (uxx)(xyz.x + 1);
    const uxx y0 = (uxx)((uint)xyz.y * Nx);
    const uxx yp = (uxx)(((uint)xyz.y + 1) * Nx);
    const uxx z0 = (uxx)xyz.z * (uxx)(Ny * Nx);
    const uxx zp = (uxx)(xyz.z + 1) * (uxx)(Ny * Nx);
    uxx j[8];
    j[0] = x0 + y0 + z0;
    j[1] = xp + y0 + z0;
    j[2] = xp + y0 + zp;
    j[3] = x0 + y0 + zp;
    j[4] = x0 + yp + z0;
    j[5] = xp + yp + z0;
    j[6] = xp + yp + zp;
    j[7] = x0 + yp + zp;
    uchar flags_cell = 0u;
    for (uint i = 0u; i < 8u; i++)
      flags_cell |= flags[j[i]];
    if (!(flags_cell & (TYPE_S | TYPE_E | TYPE_I)))
      continue;
    float v[8];
    for (uint i = 0u; i < 8u; i++)
      v[i] = phi[j[i]];
    float3 triangles[15];
    const uint tn = marching_cubes(v, 0.5f, triangles);
    if (tn == 0u)
      continue;
    const float3 offset = (float3)((float)xyz.x + 0.5f - 0.5f * (float)Nx,
                                   (float)xyz.y + 0.5f - 0.5f * (float)Ny,
                                   (float)xyz.z + 0.5f - 0.5f * (float)Nz);
    for (uint i = 0u; i < tn; i++) {
      const float3 p0 = triangles[3u * i] + offset;
      const float3 p1 = triangles[3u * i + 1u] + offset;
      const float3 p2 = triangles[3u * i + 2u] + offset;
      const float intersect = intersect_triangle_bidirectional(r, p0, p1, p2);
      if (intersect > 0.0f) {
        const uxx xq = (uxx)(((uint)xyz.x + 2u) % Nx);
        const uxx xm = (uxx)(((uint)xyz.x + Nx - 1u) % Nx);
        const uxx yq = (uxx)((((uint)xyz.y + 2u) % Ny) * Nx);
        const uxx ym = (uxx)((((uint)xyz.y + Ny - 1u) % Ny) * Nx);
        const uxx zq = (uxx)(((uint)xyz.z + 2u) % Nz) * (uxx)(Ny * Nx);
        const uxx zm = (uxx)(((uint)xyz.z + Nz - 1u) % Nz) * (uxx)(Ny * Nx);
        float3 n[8];
        n[0] = (float3)(phi[xm + y0 + z0] - v[1], phi[x0 + ym + z0] - v[4],
                        phi[x0 + y0 + zm] - v[3]);
        n[1] = (float3)(v[0] - phi[xq + y0 + z0], phi[xp + ym + z0] - v[5],
                        phi[xp + y0 + zm] - v[2]);
        n[2] = (float3)(v[3] - phi[xq + y0 + zp], phi[xp + ym + zp] - v[6],
                        v[1] - phi[xp + y0 + zq]);
        n[3] = (float3)(phi[xm + y0 + zp] - v[2], phi[x0 + ym + zp] - v[7],
                        v[0] - phi[x0 + y0 + zq]);
        n[4] = (float3)(phi[xm + yp + z0] - v[5], v[0] - phi[x0 + yq + z0],
                        phi[x0 + yp + zm] - v[7]);
        n[5] = (float3)(v[4] - phi[xq + yp + z0], v[1] - phi[xp + yq + z0],
                        phi[xp + yp + zm] - v[6]);
        n[6] = (float3)(v[7] - phi[xq + yp + zp], v[2] - phi[xp + yq + zp],
                        v[5] - phi[xp + yp + zq]);
        n[7] = (float3)(phi[xm + yp + zp] - v[6], v[3] - phi[x0 + yq + zp],
                        v[4] - phi[x0 + yp + zq]);
        const float3 p = r.origin + intersect * r.direction - offset;
        *normal = normalize(trilinear3(p - floor(p), n));
        return intersect;
      }
    }
  }
  const float intersect = intersect_cuboid_inside_with_normal(
      r, (float3)(0.0f, 0.0f, 0.0f), (float)Nx - 1.0f, (float)Ny - 1.0f,
      (float)Nz - 1.0f, normal);
  return intersect > 0.0f ? (interpolate_phi(r.origin + intersect * r.direction,
                                             phi, Nx, Ny, Nz) > 0.5f
                                 ? intersect
                                 : -1.0f)
                          : -1.0f;
}

bool raytrace_phi_mirror(const ray ray_in, ray *ray_reflect,
                         const global float *phi, const global uchar *flags,
                         const global int *skybox, const uint Nx, const uint Ny,
                         const uint Nz) {
  float3 normal;
  float d = ray_grid_traverse(ray_in, phi, flags, &normal, Nx, Ny, Nz);
  if (d == -1.0f)
    return false;
  ray_reflect->origin = ray_in.origin + (d - 0.005f) * ray_in.direction;
  ray_reflect->direction = reflect(ray_in.direction, normal);
  return true;
}

bool raytrace_phi(const ray ray_in, ray *ray_reflect, ray *ray_transmit,
                  float *reflectivity, float *transmissivity,
                  const global float *phi, const global uchar *flags,
                  const global int *skybox, const uint Nx, const uint Ny,
                  const uint Nz) {
  float3 normal;
  float d = ray_grid_traverse(ray_in, phi, flags, &normal, Nx, Ny, Nz);
  if (d == -1.0f)
    return false;
  const float ray_in_normal = dot(ray_in.direction, normal);
  const bool is_inside = ray_in_normal > 0.0f;
  ray_reflect->origin = ray_in.origin + (d - 0.005f) * ray_in.direction;
  ray_reflect->direction = reflect(ray_in.direction, normal);
  ray ray_internal;
  ray_internal.origin = ray_in.origin + (d + 0.005f) * ray_in.direction;
  ray_internal.direction = refract(ray_in.direction, normal, def_n);
  const float wr =
      clamp(sq(cb(2.0f * acospi(fabs(ray_in_normal)))), 0.0f, 1.0f);
  if (is_inside) {
    const float3 ray_internal_origin = ray_internal.origin;
    ray_internal.origin = ray_reflect->origin;
    ray_internal.direction = ray_reflect->direction;
    ray_reflect->origin = ray_internal_origin;
    ray_reflect->direction = refract(ray_in.direction, -normal, 1.0f / def_n);
    if (sq(1.0f / def_n) - 1.0f + sq(ray_in_normal) >= 0.0f) {
      ray_transmit->origin = ray_reflect->origin;
      ray_transmit->direction = ray_reflect->direction;
      *reflectivity = 0.0f;
      *transmissivity = exp(def_attenuation * d);
      return true;
    }
  }
  float d_internal = d;
  d = ray_grid_traverse(ray_internal, phi, flags, &normal, Nx, Ny, Nz);
  ray_transmit->origin =
      d != -1.0f ? ray_internal.origin + (d + 0.005f) * ray_internal.direction
                 : ray_internal.origin;
  ray_transmit->direction =
      d != -1.0f || is_inside
          ? refract(ray_internal.direction, -normal, 1.0f / def_n)
          : ray_internal.direction;
  *reflectivity = is_inside ? 0.0f : wr;
  *transmissivity =
      d != -1.0f || is_inside
          ? exp(def_attenuation * ((float)is_inside * d_internal + d))
          : (float)(def_attenuation == 0.0f);
  return true;
}

bool is_above_plane(const float3 point, const float3 plane_p,
                    const float3 plane_n) {
  return dot(point - plane_p, plane_n) >= 0.0f;
}

bool is_below_plane(const float3 point, const float3 plane_p,
                    const float3 plane_n) {
  return dot(point - plane_p, plane_n) <= 0.0f;
}

bool is_in_camera_frustrum(const float3 p, const float *camera_cache) {
  const float zoom = camera_cache[0];
  const float dis = camera_cache[1];
  const float3 pos =
      (float3)(camera_cache[2], camera_cache[3], camera_cache[4]) -
      (float3)(def_domain_offset_x, def_domain_offset_y, def_domain_offset_z);
  const float3 Rx = (float3)(camera_cache[5], camera_cache[6], camera_cache[7]);
  const float3 Ry =
      (float3)(camera_cache[8], camera_cache[9], camera_cache[10]);
  const float3 Rz =
      (float3)(camera_cache[11], camera_cache[12], camera_cache[13]);
  const bool vr = (as_int(camera_cache[14]) >> 31) & 0x1;
  const float rtv = (as_int(camera_cache[14]) >> 30) & 0x1 ? 2.0f : 1.0f;
  const float3 p0 = (float3)(0.0f, 0.0f, dis / zoom);
  const float3 camera_center = Rx * p0.x + Ry * p0.y + Rz * p0.z + pos;
  const float x_left = !vr ? (float)(-(int)def_screen_width / 2)
                           : ((float)(-(int)def_screen_width / 2) +
                              (float)(def_screen_width / 4u)) *
                                 rtv;
  const float x_right = !vr ? (float)((int)def_screen_width / 2 - 1)
                            : ((float)((int)def_screen_width / 2 - 1) -
                               (float)(def_screen_width / 4u)) *
                                  rtv;
  const float y_top = (float)(-(int)def_screen_height / 2);
  const float y_bottom = (float)((int)def_screen_height / 2 - 1);
  const float dis_clamped = fmin(dis, 1E4f);
  float3 r00 = p0 + normalize((float3)(x_left, y_top, -dis_clamped));
  float3 r01 = p0 + normalize((float3)(x_right, y_top, -dis_clamped));
  float3 r10 = p0 + normalize((float3)(x_left, y_bottom, -dis_clamped));
  float3 r11 = p0 + normalize((float3)(x_right, y_bottom, -dis_clamped));
  r00 = Rx * r00.x + Ry * r00.y + Rz * r00.z + pos - camera_center;
  r01 = Rx * r01.x + Ry * r01.y + Rz * r01.z + pos - camera_center;
  r10 = Rx * r10.x + Ry * r10.y + Rz * r10.z + pos - camera_center;
  r11 = Rx * r11.x + Ry * r11.y + Rz * r11.z + pos - camera_center;
  const float3 plane_n_top = cross(r00, r01);
  const float3 plane_n_bottom = cross(r11, r10);
  const float3 plane_n_left = cross(r10, r00);
  const float3 plane_n_right = cross(r01, r11);
  const float3 plane_p_top = camera_center - 2.0f * plane_n_top;
  const float3 plane_p_bottom = camera_center - 2.0f * plane_n_bottom;
  const float3 plane_p_left =
      camera_center - (2.0f + 8.0f * (float)vr) * plane_n_left;
  const float3 plane_p_right =
      camera_center - (2.0f + 8.0f * (float)vr) * plane_n_right;
  return is_above_plane(p, plane_p_top, plane_n_top) &&
         is_above_plane(p, plane_p_bottom, plane_n_bottom) &&
         is_above_plane(p, plane_p_left, plane_n_left) &&
         is_above_plane(p, plane_p_right, plane_n_right);
}
#endif

uint3 coordinates(const uxx n) {
  const uint t = (uint)(n % (uxx)(def_Nx * def_Ny));
  return (uint3)(t % def_Nx, t / def_Nx, (uint)(n / (uxx)(def_Nx * def_Ny)));
}

uxx index(const uint3 xyz) {
  return (uxx)xyz.x + (uxx)(xyz.y + xyz.z * def_Ny) * (uxx)def_Nx;
}

float3 position(const uint3 xyz) {
  return (float3)((float)xyz.x + 0.5f - 0.5f * (float)def_Nx,
                  (float)xyz.y + 0.5f - 0.5f * (float)def_Ny,
                  (float)xyz.z + 0.5f - 0.5f * (float)def_Nz);
}

uint3 closest_coordinates(const float3 p) {
  return (uint3)((uint)(p.x + 1.5f * (float)def_Nx) % def_Nx,
                 (uint)(p.y + 1.5f * (float)def_Ny) % def_Ny,
                 (uint)(p.z + 1.5f * (float)def_Nz) % def_Nz);
}

float3 mirror_position(const float3 p) {
  float3 r;
  r.x = sign(p.x) * (fmod(fabs(p.x) + 0.5f * (float)def_Nx, (float)def_Nx) -
                     0.5f * (float)def_Nx);
  r.y = sign(p.y) * (fmod(fabs(p.y) + 0.5f * (float)def_Ny, (float)def_Ny) -
                     0.5f * (float)def_Ny);
  r.z = sign(p.z) * (fmod(fabs(p.z) + 0.5f * (float)def_Nz, (float)def_Nz) -
                     0.5f * (float)def_Nz);
  return r;
}

float3 mirror_distance(const float3 d) { return mirror_position(d); }

bool is_halo(const uxx n) {
  const uint3 xyz = coordinates(n);
  return ((def_Dx > 1u) & (xyz.x == 0u || xyz.x >= def_Nx - 1u)) ||
         ((def_Dy > 1u) & (xyz.y == 0u || xyz.y >= def_Ny - 1u)) ||
         ((def_Dz > 1u) & (xyz.z == 0u || xyz.z >= def_Nz - 1u));
}

bool is_halo_q(const uint3 xyz) {
  return ((def_Dx > 1u) & (xyz.x == 0u || xyz.x >= def_Nx - 2u)) ||
         ((def_Dy > 1u) & (xyz.y == 0u || xyz.y >= def_Ny - 2u)) ||
         ((def_Dz > 1u) & (xyz.z == 0u || xyz.z >= def_Nz - 2u));
}

float half_to_float_custom(const ushort x) {
  const uint e = (x & 0x7800) >> 11;
  const uint m = (x & 0x07FF) << 12;
  const uint v = as_uint((float)m) >> 23;
  return as_float((x & 0x8000) << 16 | (e != 0) * ((e + 112) << 23 | m) |
                  ((e == 0) & (m != 0)) *
                      ((v - 37) << 23 | ((m << (150 - v)) & 0x007FF000)));
}

ushort float_to_half_custom(const float x) {
  const uint b = as_uint(x) + 0x00000800;
  const uint e = (b & 0x7F800000) >> 23;
  const uint m = b & 0x007FFFFF;
  return (b & 0x80000000) >> 16 |
         (e > 112) * ((((e - 112) << 11) & 0x7800) | m >> 12) |
         ((e < 113) & (e > 100)) * ((((0x007FF800 + m) >> (124 - e)) + 1) >> 1);
}

ulong index_f(const uxx n, const uint i) { return (ulong)i * def_N + (ulong)n; }

float c(const uint i) {
  const float c[3u * def_velocity_set] = {
#if defined(D2Q9)
      0, 1,  -1, 0, 0, 1, -1, 1, -1, 0, 0, 0, 1, -1,
      1, -1, -1, 1, 0, 0, 0,  0, 0,  0, 0, 0, 0
#elif defined(D3Q15)
      0, 1, -1, 0,  0,  0, 0,  1,  -1, 1,  -1, 1, -1, -1, 1, 0,
      0, 0, 1,  -1, 0,  0, 1,  -1, 1,  -1, -1, 1, 1,  -1, 0, 0,
      0, 0, 0,  1,  -1, 1, -1, -1, 1,  1,  -1, 1, -1
#elif defined(D3Q19)
      0, 1, -1, 0,  0,  0, 0, 1,  -1, 1, -1, 0,  0,  1,  -1, 1,  -1, 0,  0, 0,
      0, 0, 1,  -1, 0,  0, 1, -1, 0,  0, 1,  -1, -1, 1,  0,  0,  1,  -1, 0, 0,
      0, 0, 0,  1,  -1, 0, 0, 1,  -1, 1, -1, 0,  0,  -1, 1,  -1, 1
#elif defined(D3Q27)
      0, 1,  -1, 0,  0, 0,  0,  1,  -1, 1,  -1, 0,  0, 1,  -1, 1,  -1,
      0, 0,  1,  -1, 1, -1, 1,  -1, -1, 1,  0,  0,  0, 1,  -1, 0,  0,
      1, -1, 0,  0,  1, -1, -1, 1,  0,  0,  1,  -1, 1, -1, 1,  -1, -1,
      1, 1,  -1, 0,  0, 0,  0,  0,  1,  -1, 0,  0,  1, -1, 1,  -1, 0,
      0, -1, 1,  -1, 1, 1,  -1, -1, 1,  1,  -1, 1,  -1
#endif
  };
  return c[i];
}

float w(const uint i) {
  const float w[def_velocity_set] = {def_w0,
#if defined(D2Q9)
                                     def_ws, def_ws, def_ws, def_ws, def_we,
                                     def_we, def_we, def_we
#elif defined(D3Q15)
                                     def_ws, def_ws, def_ws, def_ws, def_ws,
                                     def_ws, def_wc, def_wc, def_wc, def_wc,
                                     def_wc, def_wc, def_wc, def_wc
#elif defined(D3Q19)
                                     def_ws, def_ws, def_ws, def_ws, def_ws,
                                     def_ws, def_we, def_we, def_we, def_we,
                                     def_we, def_we, def_we, def_we, def_we,
                                     def_we, def_we, def_we
#elif defined(D3Q27)
                                     def_ws, def_ws, def_ws, def_ws, def_ws,
                                     def_ws, def_we, def_we, def_we, def_we,
                                     def_we, def_we, def_we, def_we, def_we,
                                     def_we, def_we, def_we, def_wc, def_wc,
                                     def_wc, def_wc, def_wc, def_wc, def_wc,
                                     def_wc
#endif
  };
  return w[i];
}

void calculate_indices(const uxx n, uxx *x0, uxx *xp, uxx *xm, uxx *y0, uxx *yp,
                       uxx *ym, uxx *z0, uxx *zp, uxx *zm) {
  const uint3 xyz = coordinates(n);
  *x0 = (uxx)xyz.x;
  *xp = (uxx)((xyz.x + 1u) % def_Nx);
  *xm = (uxx)((xyz.x + def_Nx - 1u) % def_Nx);
  *y0 = (uxx)(xyz.y * def_Nx);
  *yp = (uxx)(((xyz.y + 1u) % def_Ny) * def_Nx);
  *ym = (uxx)(((xyz.y + def_Ny - 1u) % def_Ny) * def_Nx);
  *z0 = (uxx)xyz.z * (uxx)(def_Ny * def_Nx);
  *zp = (uxx)((xyz.z + 1u) % def_Nz) * (uxx)(def_Ny * def_Nx);
  *zm = (uxx)((xyz.z + def_Nz - 1u) % def_Nz) * (uxx)(def_Ny * def_Nx);
}

void neighbors(const uxx n, uxx *j) {
  uxx x0, xp, xm, y0, yp, ym, z0, zp, zm;
  calculate_indices(n, &x0, &xp, &xm, &y0, &yp, &ym, &z0, &zp, &zm);
  j[0] = n;
#if defined(D2Q9)
  j[1] = xp + y0;
  j[2] = xm + y0;
  j[3] = x0 + yp;
  j[4] = x0 + ym;
  j[5] = xp + yp;
  j[6] = xm + ym;
  j[7] = xp + ym;
  j[8] = xm + yp;
#elif defined(D3Q15)
  j[1] = xp + y0 + z0;
  j[2] = xm + y0 + z0;
  j[3] = x0 + yp + z0;
  j[4] = x0 + ym + z0;
  j[5] = x0 + y0 + zp;
  j[6] = x0 + y0 + zm;
  j[7] = xp + yp + zp;
  j[8] = xm + ym + zm;
  j[9] = xp + yp + zm;
  j[10] = xm + ym + zp;
  j[11] = xp + ym + zp;
  j[12] = xm + yp + zm;
  j[13] = xm + yp + zp;
  j[14] = xp + ym + zm;
#elif defined(D3Q19)
  j[1] = xp + y0 + z0;
  j[2] = xm + y0 + z0;
  j[3] = x0 + yp + z0;
  j[4] = x0 + ym + z0;
  j[5] = x0 + y0 + zp;
  j[6] = x0 + y0 + zm;
  j[7] = xp + yp + z0;
  j[8] = xm + ym + z0;
  j[9] = xp + y0 + zp;
  j[10] = xm + y0 + zm;
  j[11] = x0 + yp + zp;
  j[12] = x0 + ym + zm;
  j[13] = xp + ym + z0;
  j[14] = xm + yp + z0;
  j[15] = xp + y0 + zm;
  j[16] = xm + y0 + zp;
  j[17] = x0 + yp + zm;
  j[18] = x0 + ym + zp;
#elif defined(D3Q27)
  j[1] = xp + y0 + z0;
  j[2] = xm + y0 + z0;
  j[3] = x0 + yp + z0;
  j[4] = x0 + ym + z0;
  j[5] = x0 + y0 + zp;
  j[6] = x0 + y0 + zm;
  j[7] = xp + yp + z0;
  j[8] = xm + ym + z0;
  j[9] = xp + y0 + zp;
  j[10] = xm + y0 + zm;
  j[11] = x0 + yp + zp;
  j[12] = x0 + ym + zm;
  j[13] = xp + ym + z0;
  j[14] = xm + yp + z0;
  j[15] = xp + y0 + zm;
  j[16] = xm + y0 + zp;
  j[17] = x0 + yp + zm;
  j[18] = x0 + ym + zp;
  j[19] = xp + yp + zp;
  j[20] = xm + ym + zm;
  j[21] = xp + yp + zm;
  j[22] = xm + ym + zp;
  j[23] = xp + ym + zp;
  j[24] = xm + yp + zm;
  j[25] = xm + yp + zp;
  j[26] = xp + ym + zm;
#endif
}

float3 load3(const uxx n, const global float *v) {
  return (float3)(v[n], v[def_N + (ulong)n], v[2ul * def_N + (ulong)n]);
}

float3 closest_u(const float3 p, const global float *u) {
  return load3(index(closest_coordinates(p)), u);
}

float3 interpolate_u(const float3 p, const global float *u) {
  const float xa = p.x - 0.5f + 1.5f * (float)def_Nx,
              ya = p.y - 0.5f + 1.5f * (float)def_Ny,
              za = p.z - 0.5f + 1.5f * (float)def_Nz;
  const uint xb = (uint)xa, yb = (uint)ya, zb = (uint)za;
  const float3 pn = (float3)(xa - (float)xb, ya - (float)yb, za - (float)zb);
  float3 un[8];
  for (uint c = 0u; c < 8u; c++) {
    const uint i = (c & 0x04u) >> 2, j = (c & 0x02u) >> 1, k = c & 0x01u;
    const uint x = (xb + i) % def_Nx, y = (yb + j) % def_Ny,
               z = (zb + k) % def_Nz;
    const uxx n = (uxx)x + (uxx)(y + z * def_Ny) * (uxx)def_Nx;
    un[c] = load3(n, u);
  }
  return trilinear3(pn, un);
}

float calculate_Q_cached(const float3 u0, const float3 u1, const float3 u2,
                         const float3 u3, const float3 u4, const float3 u5) {
  const float duxdx = u0.x - u1.x, duydx = u0.y - u1.y, duzdx = u0.z - u1.z;
  const float duxdy = u2.x - u3.x, duydy = u2.y - u3.y, duzdy = u2.z - u3.z;
  const float duxdz = u4.x - u5.x, duydz = u4.y - u5.y, duzdz = u4.z - u5.z;
  const float omega_xy = duxdy - duydx, omega_xz = duxdz - duzdx,
              omega_yz = duydz - duzdy;
  const float s_xx2 = duxdx, s_yy2 = duydy, s_zz2 = duzdz;
  const float s_xy = duxdy + duydx, s_xz = duxdz + duzdx, s_yz = duydz + duzdy;
  const float omega2 = sq(omega_xy) + sq(omega_xz) + sq(omega_yz);
  const float s2 = 2.0f * (sq(s_xx2) + sq(s_yy2) + sq(s_zz2)) + sq(s_xy) +
                   sq(s_xz) + sq(s_yz);
  return 0.25f * (omega2 - s2);
}

float calculate_Q(const uxx n, const global float *u) {
  uxx x0, xp, xm, y0, yp, ym, z0, zp, zm;
  calculate_indices(n, &x0, &xp, &xm, &y0, &yp, &ym, &z0, &zp, &zm);
  uxx j[6];
  j[0] = xp + y0 + z0;
  j[1] = xm + y0 + z0;
  j[2] = x0 + yp + z0;
  j[3] = x0 + ym + z0;
  j[4] = x0 + y0 + zp;
  j[5] = x0 + y0 + zm;
  return calculate_Q_cached(load3(j[0], u), load3(j[1], u), load3(j[2], u),
                            load3(j[3], u), load3(j[4], u), load3(j[5], u));
}

void calculate_f_eq(const float rho, float ux, float uy, float uz, float *feq) {
  const float rhom1 = rho - 1.0f;
#ifndef D2Q9
  const float c3 = -3.0f * (sq(ux) + sq(uy) + sq(uz));
  uz *= 3.0f;
#else
  const float c3 = -3.0f * (sq(ux) + sq(uy));
#endif
  ux *= 3.0f;
  uy *= 3.0f;
  feq[0] = def_w0 * fma(rho, 0.5f * c3, rhom1);
#if defined(D2Q9)
  const float u0 = ux + uy, u1 = ux - uy;
  const float rhos = def_ws * rho, rhoe = def_we * rho, rhom1s = def_ws * rhom1,
              rhom1e = def_we * rhom1;
  feq[1] = fma(rhos, fma(0.5f, fma(ux, ux, c3), ux), rhom1s);
  feq[2] = fma(rhos, fma(0.5f, fma(ux, ux, c3), -ux), rhom1s);
  feq[3] = fma(rhos, fma(0.5f, fma(uy, uy, c3), uy), rhom1s);
  feq[4] = fma(rhos, fma(0.5f, fma(uy, uy, c3), -uy), rhom1s);
  feq[5] = fma(rhoe, fma(0.5f, fma(u0, u0, c3), u0), rhom1e);
  feq[6] = fma(rhoe, fma(0.5f, fma(u0, u0, c3), -u0), rhom1e);
  feq[7] = fma(rhoe, fma(0.5f, fma(u1, u1, c3), u1), rhom1e);
  feq[8] = fma(rhoe, fma(0.5f, fma(u1, u1, c3), -u1), rhom1e);
#elif defined(D3Q15)
  const float u0 = ux + uy + uz, u1 = ux + uy - uz, u2 = ux - uy + uz,
              u3 = -ux + uy + uz;
  const float rhos = def_ws * rho, rhoc = def_wc * rho, rhom1s = def_ws * rhom1,
              rhom1c = def_wc * rhom1;
  feq[1] = fma(rhos, fma(0.5f, fma(ux, ux, c3), ux), rhom1s);
  feq[2] = fma(rhos, fma(0.5f, fma(ux, ux, c3), -ux), rhom1s);
  feq[3] = fma(rhos, fma(0.5f, fma(uy, uy, c3), uy), rhom1s);
  feq[4] = fma(rhos, fma(0.5f, fma(uy, uy, c3), -uy), rhom1s);
  feq[5] = fma(rhos, fma(0.5f, fma(uz, uz, c3), uz), rhom1s);
  feq[6] = fma(rhos, fma(0.5f, fma(uz, uz, c3), -uz), rhom1s);
  feq[7] = fma(rhoc, fma(0.5f, fma(u0, u0, c3), u0), rhom1c);
  feq[8] = fma(rhoc, fma(0.5f, fma(u0, u0, c3), -u0), rhom1c);
  feq[9] = fma(rhoc, fma(0.5f, fma(u1, u1, c3), u1), rhom1c);
  feq[10] = fma(rhoc, fma(0.5f, fma(u1, u1, c3), -u1), rhom1c);
  feq[11] = fma(rhoc, fma(0.5f, fma(u2, u2, c3), u2), rhom1c);
  feq[12] = fma(rhoc, fma(0.5f, fma(u2, u2, c3), -u2), rhom1c);
  feq[13] = fma(rhoc, fma(0.5f, fma(u3, u3, c3), u3), rhom1c);
  feq[14] = fma(rhoc, fma(0.5f, fma(u3, u3, c3), -u3), rhom1c);
#elif defined(D3Q19)
  const float u0 = ux + uy, u1 = ux + uz, u2 = uy + uz, u3 = ux - uy,
              u4 = ux - uz, u5 = uy - uz;
  const float rhos = def_ws * rho, rhoe = def_we * rho, rhom1s = def_ws * rhom1,
              rhom1e = def_we * rhom1;
  feq[1] = fma(rhos, fma(0.5f, fma(ux, ux, c3), ux), rhom1s);
  feq[2] = fma(rhos, fma(0.5f, fma(ux, ux, c3), -ux), rhom1s);
  feq[3] = fma(rhos, fma(0.5f, fma(uy, uy, c3), uy), rhom1s);
  feq[4] = fma(rhos, fma(0.5f, fma(uy, uy, c3), -uy), rhom1s);
  feq[5] = fma(rhos, fma(0.5f, fma(uz, uz, c3), uz), rhom1s);
  feq[6] = fma(rhos, fma(0.5f, fma(uz, uz, c3), -uz), rhom1s);
  feq[7] = fma(rhoe, fma(0.5f, fma(u0, u0, c3), u0), rhom1e);
  feq[8] = fma(rhoe, fma(0.5f, fma(u0, u0, c3), -u0), rhom1e);
  feq[9] = fma(rhoe, fma(0.5f, fma(u1, u1, c3), u1), rhom1e);
  feq[10] = fma(rhoe, fma(0.5f, fma(u1, u1, c3), -u1), rhom1e);
  feq[11] = fma(rhoe, fma(0.5f, fma(u2, u2, c3), u2), rhom1e);
  feq[12] = fma(rhoe, fma(0.5f, fma(u2, u2, c3), -u2), rhom1e);
  feq[13] = fma(rhoe, fma(0.5f, fma(u3, u3, c3), u3), rhom1e);
  feq[14] = fma(rhoe, fma(0.5f, fma(u3, u3, c3), -u3), rhom1e);
  feq[15] = fma(rhoe, fma(0.5f, fma(u4, u4, c3), u4), rhom1e);
  feq[16] = fma(rhoe, fma(0.5f, fma(u4, u4, c3), -u4), rhom1e);
  feq[17] = fma(rhoe, fma(0.5f, fma(u5, u5, c3), u5), rhom1e);
  feq[18] = fma(rhoe, fma(0.5f, fma(u5, u5, c3), -u5), rhom1e);
#elif defined(D3Q27)
  const float u0 = ux + uy, u1 = ux + uz, u2 = uy + uz, u3 = ux - uy,
              u4 = ux - uz, u5 = uy - uz, u6 = ux + uy + uz, u7 = ux + uy - uz,
              u8 = ux - uy + uz, u9 = -ux + uy + uz;
  const float rhos = def_ws * rho, rhoe = def_we * rho, rhoc = def_wc * rho,
              rhom1s = def_ws * rhom1, rhom1e = def_we * rhom1,
              rhom1c = def_wc * rhom1;
  feq[1] = fma(rhos, fma(0.5f, fma(ux, ux, c3), ux), rhom1s);
  feq[2] = fma(rhos, fma(0.5f, fma(ux, ux, c3), -ux), rhom1s);
  feq[3] = fma(rhos, fma(0.5f, fma(uy, uy, c3), uy), rhom1s);
  feq[4] = fma(rhos, fma(0.5f, fma(uy, uy, c3), -uy), rhom1s);
  feq[5] = fma(rhos, fma(0.5f, fma(uz, uz, c3), uz), rhom1s);
  feq[6] = fma(rhos, fma(0.5f, fma(uz, uz, c3), -uz), rhom1s);
  feq[7] = fma(rhoe, fma(0.5f, fma(u0, u0, c3), u0), rhom1e);
  feq[8] = fma(rhoe, fma(0.5f, fma(u0, u0, c3), -u0), rhom1e);
  feq[9] = fma(rhoe, fma(0.5f, fma(u1, u1, c3), u1), rhom1e);
  feq[10] = fma(rhoe, fma(0.5f, fma(u1, u1, c3), -u1), rhom1e);
  feq[11] = fma(rhoe, fma(0.5f, fma(u2, u2, c3), u2), rhom1e);
  feq[12] = fma(rhoe, fma(0.5f, fma(u2, u2, c3), -u2), rhom1e);
  feq[13] = fma(rhoe, fma(0.5f, fma(u3, u3, c3), u3), rhom1e);
  feq[14] = fma(rhoe, fma(0.5f, fma(u3, u3, c3), -u3), rhom1e);
  feq[15] = fma(rhoe, fma(0.5f, fma(u4, u4, c3), u4), rhom1e);
  feq[16] = fma(rhoe, fma(0.5f, fma(u4, u4, c3), -u4), rhom1e);
  feq[17] = fma(rhoe, fma(0.5f, fma(u5, u5, c3), u5), rhom1e);
  feq[18] = fma(rhoe, fma(0.5f, fma(u5, u5, c3), -u5), rhom1e);
  feq[19] = fma(rhoc, fma(0.5f, fma(u6, u6, c3), u6), rhom1c);
  feq[20] = fma(rhoc, fma(0.5f, fma(u6, u6, c3), -u6), rhom1c);
  feq[21] = fma(rhoc, fma(0.5f, fma(u7, u7, c3), u7), rhom1c);
  feq[22] = fma(rhoc, fma(0.5f, fma(u7, u7, c3), -u7), rhom1c);
  feq[23] = fma(rhoc, fma(0.5f, fma(u8, u8, c3), u8), rhom1c);
  feq[24] = fma(rhoc, fma(0.5f, fma(u8, u8, c3), -u8), rhom1c);
  feq[25] = fma(rhoc, fma(0.5f, fma(u9, u9, c3), u9), rhom1c);
  feq[26] = fma(rhoc, fma(0.5f, fma(u9, u9, c3), -u9), rhom1c);
#endif
}

void calculate_rho_u(const float *f, float *rhon, float *uxn, float *uyn,
                     float *uzn) {
  float rho = f[0], ux, uy, uz;
  for (uint i = 1u; i < def_velocity_set; i++)
    rho += f[i];
  rho += 1.0f;
#if defined(D2Q9)
  ux = f[1] - f[2] + f[5] - f[6] + f[7] - f[8];
  uy = f[3] - f[4] + f[5] - f[6] + f[8] - f[7];
  uz = 0.0f;
#elif defined(D3Q15)
  ux = f[1] - f[2] + f[7] - f[8] + f[9] - f[10] + f[11] - f[12] + f[14] - f[13];
  uy = f[3] - f[4] + f[7] - f[8] + f[9] - f[10] + f[12] - f[11] + f[13] - f[14];
  uz = f[5] - f[6] + f[7] - f[8] + f[10] - f[9] + f[11] - f[12] + f[13] - f[14];
#elif defined(D3Q19)
  ux = f[1] - f[2] + f[7] - f[8] + f[9] - f[10] + f[13] - f[14] + f[15] - f[16];
  uy =
      f[3] - f[4] + f[7] - f[8] + f[11] - f[12] + f[14] - f[13] + f[17] - f[18];
  uz = f[5] - f[6] + f[9] - f[10] + f[11] - f[12] + f[16] - f[15] + f[18] -
       f[17];
#elif defined(D3Q27)
  ux = f[1] - f[2] + f[7] - f[8] + f[9] - f[10] + f[13] - f[14] + f[15] -
       f[16] + f[19] - f[20] + f[21] - f[22] + f[23] - f[24] + f[26] - f[25];
  uy = f[3] - f[4] + f[7] - f[8] + f[11] - f[12] + f[14] - f[13] + f[17] -
       f[18] + f[19] - f[20] + f[21] - f[22] + f[24] - f[23] + f[25] - f[26];
  uz = f[5] - f[6] + f[9] - f[10] + f[11] - f[12] + f[16] - f[15] + f[18] -
       f[17] + f[19] - f[20] + f[22] - f[21] + f[23] - f[24] + f[25] - f[26];
#endif
  *rhon = rho;
  *uxn = ux / rho;
  *uyn = uy / rho;
  *uzn = uz / rho;
}
#ifdef VOLUME_FORCE

void calculate_forcing_terms(const float ux, const float uy, const float uz,
                             const float fx, const float fy, const float fz,
                             float *Fin) {
#ifdef D2Q9
  const float uF = -0.33333334f * fma(ux, fx, uy * fy);
#else
  const float uF = -0.33333334f * fma(ux, fx, fma(uy, fy, uz * fz));
#endif
  Fin[0] = 9.0f * def_w0 * uF;
  for (uint i = 1u; i < def_velocity_set; i++) {
    Fin[i] = 9.0f * w(i) *
             fma(c(i) * fx + c(def_velocity_set + i) * fy +
                     c(2u * def_velocity_set + i) * fz,
                 c(i) * ux + c(def_velocity_set + i) * uy +
                     c(2u * def_velocity_set + i) * uz + 0.33333334f,
                 uF);
  }
}
#endif

#ifdef MOVING_BOUNDARIES

void apply_moving_boundaries(float *fhn, const uxx *j, const global float *u,
                             const global uchar *flags) {
  uxx ji;
  for (uint i = 1u; i < def_velocity_set; i += 2u) {
    const float w6 = -6.0f * w(i);
    ji = j[i + 1u];
    fhn[i] = (flags[ji] & TYPE_BO) == TYPE_S
                 ? fma(w6,
                       c(i + 1u) * u[ji] +
                           c(def_velocity_set + i + 1u) * u[def_N + (ulong)ji] +
                           c(2u * def_velocity_set + i + 1u) *
                               u[2ul * def_N + (ulong)ji],
                       fhn[i])
                 : fhn[i];
    ji = j[i];
    fhn[i + 1u] =
        (flags[ji] & TYPE_BO) == TYPE_S
            ? fma(w6,
                  c(i) * u[ji] +
                      c(def_velocity_set + i) * u[def_N + (ulong)ji] +
                      c(2u * def_velocity_set + i) * u[2ul * def_N + (ulong)ji],
                  fhn[i + 1u])
            : fhn[i + 1u];
  }
}
#endif

#ifdef SURFACE

void average_neighbors_non_gas(const uxx n, const global float *rho,
                               const global float *u, const global uchar *flags,
                               float *rhon, float *uxn, float *uyn,
                               float *uzn) {
  uxx j[def_velocity_set];
  neighbors(n, j);
  float rhot = 0.0f, uxt = 0.0f, uyt = 0.0f, uzt = 0.0f, counter = 0.0f;
  for (uint i = 1u; i < def_velocity_set; i++) {
    const uchar flagsji_sus = flags[j[i]] & (TYPE_SU | TYPE_S);
    if (flagsji_sus == TYPE_F || flagsji_sus == TYPE_I ||
        flagsji_sus == TYPE_IF) {
      counter += 1.0f;
      rhot += rho[j[i]];
      uxt += u[j[i]];
      uyt += u[def_N + (ulong)j[i]];
      uzt += u[2ul * def_N + (ulong)j[i]];
    }
  }
  *rhon = counter > 0.0f ? rhot / counter : 1.0f;
  *uxn = counter > 0.0f ? uxt / counter : 0.0f;
  *uyn = counter > 0.0f ? uyt / counter : 0.0f;
  *uzn = counter > 0.0f ? uzt / counter : 0.0f;
}

void average_neighbors_fluid(const uxx n, const global float *rho,
                             const global float *u, const global uchar *flags,
                             float *rhon, float *uxn, float *uyn, float *uzn) {
  uxx j[def_velocity_set];
  neighbors(n, j);
  float rhot = 0.0f, uxt = 0.0f, uyt = 0.0f, uzt = 0.0f, counter = 0.0f;
  for (uint i = 1u; i < def_velocity_set; i++) {
    const uchar flagsji_su = flags[j[i]] & TYPE_SU;
    if (flagsji_su == TYPE_F) {
      counter += 1.0f;
      rhot += rho[j[i]];
      uxt += u[j[i]];
      uyt += u[def_N + (ulong)j[i]];
      uzt += u[2ul * def_N + (ulong)j[i]];
    }
  }
  *rhon = counter > 0.0f ? rhot / counter : 1.0f;
  *uxn = counter > 0.0f ? uxt / counter : 0.0f;
  *uyn = counter > 0.0f ? uyt / counter : 0.0f;
  *uzn = counter > 0.0f ? uzt / counter : 0.0f;
}

float calculate_phi(const float rhon, const float massn, const uchar flagsn) {
  return flagsn & TYPE_F ? 1.0f
         : flagsn & TYPE_I
             ? rhon > 0.0f ? clamp(massn / rhon, 0.0f, 1.0f) : 0.5f
             : 0.0f;
}

float3 calculate_normal_py(const float *phij) {
  float3 n;
#ifdef D2Q9
  n.x = 2.0f * (phij[2] - phij[1]) + phij[6] - phij[5] + phij[8] - phij[7];
  n.y = 2.0f * (phij[4] - phij[3]) + phij[6] - phij[5] + phij[7] - phij[8];
  n.z = 0.0f;
#else
  n.x = 4.0f * (phij[2] - phij[1]) +
        2.0f * (phij[8] - phij[7] + phij[10] - phij[9] + phij[14] - phij[13] +
                phij[16] - phij[15]) +
        phij[20] - phij[19] + phij[22] - phij[21] + phij[24] - phij[23] +
        phij[25] - phij[26];
  n.y = 4.0f * (phij[4] - phij[3]) +
        2.0f * (phij[8] - phij[7] + phij[12] - phij[11] + phij[13] - phij[14] +
                phij[18] - phij[17]) +
        phij[20] - phij[19] + phij[22] - phij[21] + phij[23] - phij[24] +
        phij[26] - phij[25];
  n.z = 4.0f * (phij[6] - phij[5]) +
        2.0f * (phij[10] - phij[9] + phij[12] - phij[11] + phij[15] - phij[16] +
                phij[17] - phij[18]) +
        phij[20] - phij[19] + phij[21] - phij[22] + phij[24] - phij[23] +
        phij[26] - phij[25];
#endif
  return normalize(n);
}

float plic_cube_reduced(const float V, const float n1, const float n2,
                        const float n3) {
  const float n12 = n1 + n2, n3V = n3 * V;
  if (n12 <= 2.0f * n3V)
    return n3V + 0.5f * n12;
  const float sqn1 = sq(n1), n26 = 6.0f * n2, v1 = sqn1 / n26;
  if (v1 <= n3V && n3V < v1 + 0.5f * (n2 - n1))
    return 0.5f * (n1 + sqrt(sqn1 + 8.0f * n2 * (n3V - v1)));
  const float V6 = n1 * n26 * n3V;
  if (n3V < v1)
    return cbrt(V6);
  const float v3 = n3 < n12
                       ? (sq(n3) * (3.0f * n12 - n3) + sqn1 * (n1 - 3.0f * n3) +
                          sq(n2) * (n2 - 3.0f * n3)) /
                             (n1 * n26)
                       : 0.5f * n12;
  const float sqn12 = sqn1 + sq(n2), V6cbn12 = V6 - cb(n1) - cb(n2);
  const bool case34 = n3V < v3;
  const float a = case34 ? V6cbn12 : 0.5f * (V6cbn12 - cb(n3));
  const float b = case34 ? sqn12 : 0.5f * (sqn12 + sq(n3));
  const float c = case34 ? n12 : 0.5f;
  const float t = sqrt(sq(c) - b);
  return c -
         2.0f * t *
             sin(0.33333334f * asin((cb(c) - 0.5f * a - 1.5f * b * c) / cb(t)));
}

float plic_cube(const float V0, const float3 n) {
  const float ax = fabs(n.x), ay = fabs(n.y), az = fabs(n.z),
              V = 0.5f - fabs(V0 - 0.5f), l = ax + ay + az;
  const float n1 = fmin(fmin(ax, ay), az) / l;
  const float n3 = fmax(fmax(ax, ay), az) / l;
  const float n2 = fdim(1.0f, n1 + n3);
  const float d = plic_cube_reduced(V, n1, n2, n3);
  return l * copysign(0.5f - d, V0 - 0.5f);
}

void get_remaining_neighbor_phij(const uxx n, const float *phit,
                                 const global float *phi, float *phij) {
#ifndef D3Q27
  uxx x0, xp, xm, y0, yp, ym, z0, zp, zm;
  calculate_indices(n, &x0, &xp, &xm, &y0, &yp, &ym, &z0, &zp, &zm);
#endif

#if defined(D3Q15)
  uxx j[12];
  j[0] = xp + yp + z0;
  j[1] = xm + ym + z0;
  j[2] = xp + y0 + zp;
  j[3] = xm + y0 + zm;
  j[4] = x0 + yp + zp;
  j[5] = x0 + ym + zm;
  j[6] = xp + ym + z0;
  j[7] = xm + yp + z0;
  j[8] = xp + y0 + zm;
  j[9] = xm + y0 + zp;
  j[10] = x0 + yp + zm;
  j[11] = x0 + ym + zp;
  for (uint i = 0u; i < 7u; i++)
    phij[i] = phit[i];
  for (uint i = 7u; i < 19u; i++)
    phij[i] = phi[j[i - 7u]];
  for (uint i = 19u; i < 27u; i++)
    phij[i] = phit[i - 12u];
#elif defined(D3Q19)
  uxx j[8];
  j[0] = xp + yp + zp;
  j[1] = xm + ym + zm;
  j[2] = xp + yp + zm;
  j[3] = xm + ym + zp;
  j[4] = xp + ym + zp;
  j[5] = xm + yp + zm;
  j[6] = xm + yp + zp;
  j[7] = xp + ym + zm;
  for (uint i = 0u; i < 19u; i++)
    phij[i] = phit[i];
  for (uint i = 19u; i < 27u; i++)
    phij[i] = phi[j[i - 19u]];
#elif defined(D3Q27)
  for (uint i = 0u; i < def_velocity_set; i++)
    phij[i] = phit[i];
#endif
}

float c_D3Q27(const uint i) {
  const float c[3 * 27] = {
      0, 1,  -1, 0,  0, 0,  0,  1,  -1, 1,  -1, 0,  0, 1,  -1, 1,  -1,
      0, 0,  1,  -1, 1, -1, 1,  -1, -1, 1,  0,  0,  0, 1,  -1, 0,  0,
      1, -1, 0,  0,  1, -1, -1, 1,  0,  0,  1,  -1, 1, -1, 1,  -1, -1,
      1, 1,  -1, 0,  0, 0,  0,  0,  1,  -1, 0,  0,  1, -1, 1,  -1, 0,
      0, -1, 1,  -1, 1, 1,  -1, -1, 1,  1,  -1, 1,  -1};
  return c[i];
}

float calculate_curvature(const uxx n, const float *phit,
                          const global float *phi) {
#ifndef D2Q9
  float phij[27];
  get_remaining_neighbor_phij(n, phit, phi, phij);
  const float3 bz = calculate_normal_py(phij);
  const float3 rn = (float3)(0.56270900f, 0.32704452f, 0.75921047f);
  const float3 by = normalize(cross(bz, rn));
  const float3 bx = cross(by, bz);
  uint number = 0;
  float3 p[24];
  const float center_offset = plic_cube(phij[0], bz);
  for (uint i = 1u; i < 27u; i++) {
    if (phij[i] > 0.0f && phij[i] < 1.0f) {
      const float3 ei =
          (float3)(c_D3Q27(i), c_D3Q27(27u + i), c_D3Q27(2u * 27u + i));
      const float offset = plic_cube(phij[i], bz) - center_offset;
      p[number++] = (float3)(dot(ei, bx), dot(ei, by), dot(ei, bz) + offset);
    }
  }
  float M[25], x[5] = {0.0f, 0.0f, 0.0f, 0.0f, 0.0f},
               b[5] = {0.0f, 0.0f, 0.0f, 0.0f, 0.0f};
  for (uint i = 0u; i < 25u; i++)
    M[i] = 0.0f;
  for (uint i = 0u; i < number; i++) {
    const float x = p[i].x, y = p[i].y, z = p[i].z, x2 = x * x, y2 = y * y,
                x3 = x2 * x, y3 = y2 * y;
    M[0] += x2 * x2;
    M[1] += x2 * y2;
    M[2] += x3 * y;
    M[3] += x3;
    M[4] += x2 * y;
    b[0] += x2 * z;
    M[6] += y2 * y2;
    M[7] += x * y3;
    M[8] += x * y2;
    M[9] += y3;
    b[1] += y2 * z;
    M[12] += x2 * y2;
    M[13] += x2 * y;
    M[14] += x * y2;
    b[2] += x * y * z;
    M[18] += x2;
    M[19] += x * y;
    b[3] += x * z;
    M[24] += y2;
    b[4] += y * z;
  }
  for (uint i = 1u; i < 5u; i++) {
    for (uint j = 0u; j < i; j++)
      M[i * 5 + j] = M[j * 5 + i];
  }
  if (number >= 5u)
    lu_solve(M, x, b, 5, 5);
  else
    lu_solve(M, x, b, 5, min(5u, number));
  const float A = x[0], B = x[1], C = x[2], H = x[3], I = x[4];
  const float K = (A * (I * I + 1.0f) + B * (H * H + 1.0f) - C * H * I) *
                  cb(rsqrt(H * H + I * I + 1.0f));
#else
  const float3 by = calculate_normal_py(phit);
  const float3 bx = cross(by, (float3)(0.0f, 0.0f, 1.0f));
  uint number = 0u;
  float2 p[6];
  const float center_offset = plic_cube(phit[0], by);
  for (uint i = 1u; i < 9u; i++) {
    if (phit[i] > 0.0f && phit[i] < 1.0f) {
      const float3 ei = (float3)(c(i), c(9u + i), 0.0f);
      const float offset = plic_cube(phit[i], by) - center_offset;
      p[number++] = (float2)(dot(ei, bx), dot(ei, by) + offset);
    }
  }
  float M[4] = {0.0f, 0.0f, 0.0f, 0.0f}, x[2] = {0.0f, 0.0f},
        b[2] = {0.0f, 0.0f};
  for (uint i = 0u; i < number; i++) {
    const float x = p[i].x, y = p[i].y, x2 = x * x, x3 = x2 * x;
    M[0] += x2 * x2;
    M[1] += x3;
    b[0] += x2 * y;
    M[3] += x2;
    b[1] += x * y;
  }
  M[2] = M[1];
  if (number >= 2u)
    lu_solve(M, x, b, 2, 2);
  else
    lu_solve(M, x, b, 2, min(2u, number));
  const float A = x[0], H = x[1];
  const float K = 2.0f * A * cb(rsqrt(H * H + 1.0f));
#endif
  return clamp(K, -1.0f, 1.0f);
}
#endif

#ifdef TEMPERATURE

void neighbors_temperature(const uxx n, uxx *j7) {
  uxx x0, xp, xm, y0, yp, ym, z0, zp, zm;
  calculate_indices(n, &x0, &xp, &xm, &y0, &yp, &ym, &z0, &zp, &zm);
  j7[0] = n;
  j7[1] = xp + y0 + z0;
  j7[2] = xm + y0 + z0;
  j7[3] = x0 + yp + z0;
  j7[4] = x0 + ym + z0;
  j7[5] = x0 + y0 + zp;
  j7[6] = x0 + y0 + zm;
}

void calculate_g_eq(const float T, const float ux, const float uy,
                    const float uz, float *geq) {
  const float wsT4 = 0.5f * T, wsTm1 = 0.125f * (T - 1.0f);
  geq[0] = fma(0.25f, T, -0.25f);
  geq[1] = fma(wsT4, ux, wsTm1);
  geq[2] = fma(wsT4, -ux, wsTm1);
  geq[3] = fma(wsT4, uy, wsTm1);
  geq[4] = fma(wsT4, -uy, wsTm1);
  geq[5] = fma(wsT4, uz, wsTm1);
  geq[6] = fma(wsT4, -uz, wsTm1);
}

void load_g(const uxx n, float *ghn, const global fpxx *gi, const uxx *j7,
            const ulong t) {
  ghn[0] = load(gi, index_f(n, 0u));
  for (uint i = 1u; i < 7u; i += 2u) {
    ghn[i] = load(gi, index_f(n, t % 2ul ? i : i + 1u));
    ghn[i + 1u] = load(gi, index_f(j7[i], t % 2ul ? i + 1u : i));
  }
}

void store_g(const uxx n, const float *ghn, global fpxx *gi, const uxx *j7,
             const ulong t) {
  store(gi, index_f(n, 0u), ghn[0]);
  for (uint i = 1u; i < 7u; i += 2u) {
    store(gi, index_f(j7[i], t % 2ul ? i + 1u : i), ghn[i]);
    store(gi, index_f(n, t % 2ul ? i : i + 1u), ghn[i + 1u]);
  }
}
#endif

void load_f(const uxx n, float *fhn, const global fpxx *fi, const uxx *j,
            const ulong t) {
  fhn[0] = load(fi, index_f(n, 0u));
  for (uint i = 1u; i < def_velocity_set; i += 2u) {
    fhn[i] = load(fi, index_f(n, t % 2ul ? i : i + 1u));
    fhn[i + 1u] = load(fi, index_f(j[i], t % 2ul ? i + 1u : i));
  }
}

void store_f(const uxx n, const float *fhn, global fpxx *fi, const uxx *j,
             const ulong t) {
  store(fi, index_f(n, 0u), fhn[0]);
  for (uint i = 1u; i < def_velocity_set; i += 2u) {
    store(fi, index_f(j[i], t % 2ul ? i + 1u : i), fhn[i]);
    store(fi, index_f(n, t % 2ul ? i : i + 1u), fhn[i + 1u]);
  }
}
#ifdef SURFACE

void load_f_outgoing(const uxx n, float *fon, const global fpxx *fi,
                     const uxx *j, const ulong t) {
  for (uint i = 1u; i < def_velocity_set; i += 2u) {
    fon[i] = load(fi, index_f(j[i], t % 2ul ? i : i + 1u));
    fon[i + 1u] = load(fi, index_f(n, t % 2ul ? i + 1u : i));
  }
}

void store_f_reconstructed(const uxx n, const float *fhn, global fpxx *fi,
                           const uxx *j, const ulong t,
                           const uchar *flagsj_su) {
  for (uint i = 1u; i < def_velocity_set; i += 2u) {
    if (flagsj_su[i + 1u] == TYPE_G)
      store(fi, index_f(n, t % 2ul ? i : i + 1u), fhn[i]);
    if (flagsj_su[i] == TYPE_G)
      store(fi, index_f(j[i], t % 2ul ? i + 1u : i), fhn[i + 1u]);
  }
}
#endif

kernel void initialize(global fpxx *fi, const global float *rho,
                       global float *u, global uchar *flags
#ifdef SURFACE
                       ,
                       global float *mass, global float *massex,
                       global float *phi
#endif

#ifdef TEMPERATURE
                       ,
                       global fpxx *gi, const global float *T
#endif

) {
  const uxx n = get_global_id(0);
  if (n >= (uxx)def_N || is_halo(n))
    return;
  uchar flagsn = flags[n];
  const uchar flagsn_bo = flagsn & TYPE_BO;
  uxx j[def_velocity_set];
  neighbors(n, j);
  uchar flagsj[def_velocity_set];
  for (uint i = 1u; i < def_velocity_set; i++)
    flagsj[i] = flags[j[i]];
  if (flagsn_bo == TYPE_S) {
    bool TYPE_ONLY_S = true;
    for (uint i = 1u; i < def_velocity_set; i++)
      TYPE_ONLY_S = TYPE_ONLY_S && (flagsj[i] & TYPE_BO) == TYPE_S;
    if (TYPE_ONLY_S) {
      u[n] = 0.0f;
      u[def_N + (ulong)n] = 0.0f;
      u[2ul * def_N + (ulong)n] = 0.0f;
    }
#ifndef MOVING_BOUNDARIES
    if (flagsn_bo == TYPE_S) {
      u[n] = 0.0f;
      u[def_N + (ulong)n] = 0.0f;
      u[2ul * def_N + (ulong)n] = 0.0f;
    }
#else
  } else if (flagsn_bo != TYPE_E) {
    bool next_to_moving_boundary = false;
    for (uint i = 1u; i < def_velocity_set; i++) {
      next_to_moving_boundary =
          next_to_moving_boundary ||
          ((flagsj[i] & TYPE_BO) == TYPE_S &&
           (u[j[i]] != 0.0f || u[def_N + (ulong)j[i]] != 0.0f ||
            u[2ul * def_N + (ulong)j[i]] != 0.0f));
    }
    flags[n] = flagsn =
        next_to_moving_boundary ? flagsn | TYPE_MS : flagsn & ~TYPE_MS;
#endif
  }
  float feq[def_velocity_set];
  calculate_f_eq(rho[n], u[n], u[def_N + (ulong)n], u[2ul * def_N + (ulong)n],
                 feq);
#ifdef SURFACE
  {
    float phin = phi[n];
    if (!(flagsn & (TYPE_S | TYPE_E | TYPE_T | TYPE_F | TYPE_I)))
      flagsn = (flagsn & ~TYPE_SU) | TYPE_G;
    if ((flagsn & TYPE_SU) == TYPE_G) {
      bool change = false;
      for (uint i = 1u; i < def_velocity_set; i++)
        change = change || (flagsj[i] & TYPE_SU) == TYPE_F;
      if (change) {
        flagsn = (flagsn & ~TYPE_SU) | TYPE_I;
        phin = 0.5f;
        float rhon, uxn, uyn, uzn;
        average_neighbors_fluid(n, rho, u, flags, &rhon, &uxn, &uyn, &uzn);
        calculate_f_eq(rhon, uxn, uyn, uzn, feq);
      }
    }
    if ((flagsn & TYPE_SU) == TYPE_G) {
      u[n] = 0.0f;
      u[def_N + (ulong)n] = 0.0f;
      u[2ul * def_N + (ulong)n] = 0.0f;
      phin = 0.0f;
    } else if ((flagsn & TYPE_SU) == TYPE_I && (phin < 0.0f || phin > 1.0f)) {
      phin = 0.5f;
    } else if ((flagsn & TYPE_SU) == TYPE_F) {
      phin = 1.0f;
    }
    phi[n] = phin;
    mass[n] = phin * rho[n];
    massex[n] = 0.0f;
    flags[n] = flagsn;
  }
#endif

#ifdef TEMPERATURE
  {
    float geq[7];
    calculate_g_eq(T[n], u[n], u[def_N + (ulong)n], u[2ul * def_N + (ulong)n],
                   geq);
    uxx j7[7];
    neighbors_temperature(n, j7);
    store_g(n, geq, gi, j7, 1ul);
  }
#endif
  store_f(n, feq, fi, j, 1ul);
}
#ifdef MOVING_BOUNDARIES

kernel void update_moving_boundaries(const global float *u,
                                     global uchar *flags) {
  const uxx n = get_global_id(0);
  if (n >= (uxx)def_N || is_halo(n))
    return;
  const uchar flagsn = flags[n];
  const uchar flagsn_bo = flagsn & TYPE_BO;
  uxx j[def_velocity_set];
  neighbors(n, j);
  uchar flagsj[def_velocity_set];
  for (uint i = 1u; i < def_velocity_set; i++)
    flagsj[i] = flags[j[i]];
  if (flagsn_bo != TYPE_S && flagsn_bo != TYPE_E && !(flagsn & TYPE_T)) {
    bool next_to_moving_boundary = false;
    for (uint i = 1u; i < def_velocity_set; i++) {
      next_to_moving_boundary =
          next_to_moving_boundary ||
          ((u[j[i]] != 0.0f || u[def_N + (ulong)j[i]] != 0.0f ||
            u[2ul * def_N + (ulong)j[i]] != 0.0f) &&
           (flagsj[i] & TYPE_BO) == TYPE_S);
    }
    flags[n] = next_to_moving_boundary ? flagsn | TYPE_MS : flagsn & ~TYPE_MS;
  }
}
#endif

kernel void stream_collide(global fpxx *fi, global float *rho, global float *u,
                           global uchar *flags, const ulong t, const float fx,
                           const float fy, const float fz
#ifdef FORCE_FIELD
                           ,
                           const global float *F
#endif

#ifdef SURFACE
                           ,
                           const global float *mass
#endif

#ifdef TEMPERATURE
                           ,
                           global fpxx *gi, global float *T
#endif

) {
  const uxx n = get_global_id(0);
  if (n >= (uxx)def_N || is_halo(n))
    return;
  const uchar flagsn = flags[n];
  const uchar flagsn_bo = flagsn & TYPE_BO, flagsn_su = flagsn & TYPE_SU;
  if (flagsn_bo == TYPE_S || flagsn_su == TYPE_G)
    return;
  uxx j[def_velocity_set];
  neighbors(n, j);
  float fhn[def_velocity_set];
  load_f(n, fhn, fi, j, t);
#ifdef MOVING_BOUNDARIES
  if (flagsn_bo == TYPE_MS)
    apply_moving_boundaries(fhn, j, u, flags);
#endif
  float rhon, uxn, uyn, uzn;
#ifndef EQUILIBRIUM_BOUNDARIES
  calculate_rho_u(fhn, &rhon, &uxn, &uyn, &uzn);
#else
  if (flagsn_bo == TYPE_E) {
    rhon = rho[n];
    uxn = u[n];
    uyn = u[def_N + (ulong)n];
    uzn = u[2ul * def_N + (ulong)n];
  } else {
    calculate_rho_u(fhn, &rhon, &uxn, &uyn, &uzn);
  }
#endif
  float fxn = fx, fyn = fy, fzn = fz;
  float Fin[def_velocity_set];
#ifdef FORCE_FIELD
  {
    fxn += F[n];
    fyn += F[def_N + (ulong)n];
    fzn += F[2ul * def_N + (ulong)n];
  }
#endif

#ifdef SURFACE
  if (flagsn_su == TYPE_I) {
    bool TYPE_NO_F = true, TYPE_NO_G = true;
    for (uint i = 1u; i < def_velocity_set; i++) {
      const uchar flagsji_su = flags[j[i]] & TYPE_SU;
      TYPE_NO_F = TYPE_NO_F && flagsji_su != TYPE_F;
      TYPE_NO_G = TYPE_NO_G && flagsji_su != TYPE_G;
    }
    const float massn = mass[n];
    if (massn > rhon || TYPE_NO_G)
      flags[n] = (flagsn & ~TYPE_SU) | TYPE_IF;
    else if (massn < 0.0f || TYPE_NO_F)
      flags[n] = (flagsn & ~TYPE_SU) | TYPE_IG;
  }
#endif

#ifdef TEMPERATURE
  {
    uxx j7[7];
    neighbors_temperature(n, j7);
    float ghn[7];
    load_g(n, ghn, gi, j7, t);
    float Tn;
    if (flagsn & TYPE_T) {
      Tn = T[n];
    } else {
      Tn = 0.0f;
      for (uint i = 0u; i < 7u; i++)
        Tn += ghn[i];
      Tn += 1.0f;
    }
    float geq[7];
    calculate_g_eq(Tn, uxn, uyn, uzn, geq);
    if (flagsn & TYPE_T) {
      for (uint i = 0u; i < 7u; i++)
        ghn[i] = geq[i];
    } else {
#ifdef UPDATE_FIELDS
      T[n] = Tn;
#endif
      for (uint i = 0u; i < 7u; i++)
        ghn[i] = fma(1.0f - def_w_T, ghn[i], def_w_T * geq[i]);
    }
    store_g(n, ghn, gi, j7, t);
    fxn -= fx * def_beta * (Tn - def_T_avg);
    fyn -= fy * def_beta * (Tn - def_T_avg);
    fzn -= fz * def_beta * (Tn - def_T_avg);
  }
#endif
  {
#ifdef VOLUME_FORCE
    const float rho2 = 0.5f / rhon;
    uxn = clamp(fma(fxn, rho2, uxn), -def_c, def_c);
    uyn = clamp(fma(fyn, rho2, uyn), -def_c, def_c);
    uzn = clamp(fma(fzn, rho2, uzn), -def_c, def_c);
    calculate_forcing_terms(uxn, uyn, uzn, fxn, fyn, fzn, Fin);
#else
    uxn = clamp(uxn, -def_c, def_c);
    uyn = clamp(uyn, -def_c, def_c);
    uzn = clamp(uzn, -def_c, def_c);
    for (uint i = 0u; i < def_velocity_set; i++)
      Fin[i] = 0.0f;
#endif
  }
#ifndef EQUILIBRIUM_BOUNDARIES

#ifdef UPDATE_FIELDS
  rho[n] = rhon;
  u[n] = uxn;
  u[def_N + (ulong)n] = uyn;
  u[2ul * def_N + (ulong)n] = uzn;
#endif

#else

#ifdef UPDATE_FIELDS
  if (flagsn_bo != TYPE_E) {
    rho[n] = rhon;
    u[n] = uxn;
    u[def_N + (ulong)n] = uyn;
    u[2ul * def_N + (ulong)n] = uzn;
  }
#endif

#endif
  float feq[def_velocity_set];
  calculate_f_eq(rhon, uxn, uyn, uzn, feq);
  float w = def_w;
#ifdef SUBGRID
  {
    const float tau0 = 1.0f / w;
    float Hxx = 0.0f, Hyy = 0.0f, Hzz = 0.0f, Hxy = 0.0f, Hxz = 0.0f,
          Hyz = 0.0f;
    for (uint i = 1u; i < def_velocity_set; i++) {
      const float fneqi = fhn[i] - feq[i];
      const float cxi = c(i), cyi = c(def_velocity_set + i),
                  czi = c(2u * def_velocity_set + i);
      Hxx += cxi * cxi * fneqi;
      Hxy += cxi * cyi * fneqi;
      Hyy += cyi * cyi * fneqi;
      Hxz += cxi * czi * fneqi;
      Hyz += cyi * czi * fneqi;
      Hzz += czi * czi * fneqi;
    }
    const float Q =
        sq(Hxx) + sq(Hyy) + sq(Hzz) + 2.0f * (sq(Hxy) + sq(Hxz) + sq(Hyz));
    w = 2.0f / (tau0 + sqrt(sq(tau0) + 0.76421222f * sqrt(Q) / rhon));
  }
#endif

#if defined(SRT)

#ifdef VOLUME_FORCE
  const float c_tau = fma(w, -0.5f, 1.0f);
  for (uint i = 0u; i < def_velocity_set; i++)
    Fin[i] *= c_tau;
#endif

#ifndef EQUILIBRIUM_BOUNDARIES
  for (uint i = 0u; i < def_velocity_set; i++)
    fhn[i] = fma(1.0f - w, fhn[i], fma(w, feq[i], Fin[i]));
#else
  for (uint i = 0u; i < def_velocity_set; i++)
    fhn[i] = flagsn_bo == TYPE_E
                 ? feq[i]
                 : fma(1.0f - w, fhn[i], fma(w, feq[i], Fin[i]));
#endif

#elif defined(TRT)
  const float wp = w;
  const float wm = 1.0f / (0.1875f / (1.0f / w - 0.5f) + 0.5f);
#ifdef VOLUME_FORCE
  const float c_taup = fma(wp, -0.25f, 0.5f), c_taum = fma(wm, -0.25f, 0.5f);
  float Fib[def_velocity_set];
  Fib[0] = Fin[0];
  for (uint i = 1u; i < def_velocity_set; i += 2u) {
    Fib[i] = Fin[i + 1u];
    Fib[i + 1u] = Fin[i];
  }
  for (uint i = 0u; i < def_velocity_set; i++)
    Fin[i] = fma(c_taup, Fin[i] + Fib[i], c_taum * (Fin[i] - Fib[i]));
#endif
  float fhb[def_velocity_set];
  float feb[def_velocity_set];
  fhb[0] = fhn[0];
  feb[0] = feq[0];
  for (uint i = 1u; i < def_velocity_set; i += 2u) {
    fhb[i] = fhn[i + 1u];
    fhb[i + 1u] = fhn[i];
    feb[i] = feq[i + 1u];
    feb[i + 1u] = feq[i];
  }
#ifndef EQUILIBRIUM_BOUNDARIES
  for (uint i = 0u; i < def_velocity_set; i++)
    fhn[i] =
        fma(0.5f * wp, feq[i] - fhn[i] + feb[i] - fhb[i],
            fma(0.5f * wm, feq[i] - feb[i] - fhn[i] + fhb[i], fhn[i] + Fin[i]));
#else
  for (uint i = 0u; i < def_velocity_set; i++)
    fhn[i] = flagsn_bo == TYPE_E
                 ? feq[i]
                 : fma(0.5f * wp, feq[i] - fhn[i] + feb[i] - fhb[i],
                       fma(0.5f * wm, feq[i] - feb[i] - fhn[i] + fhb[i],
                           fhn[i] + Fin[i]));
#endif

#endif
  store_f(n, fhn, fi, j, t);
}
#ifdef SURFACE

kernel void surface_0(global fpxx *fi, const global float *rho,
                      const global float *u, const global uchar *flags,
                      global float *mass, const global float *massex,
                      const global float *phi, const ulong t, const float fx,
                      const float fy, const float fz) {
  const uxx n = get_global_id(0);
  if (n >= (uxx)def_N || is_halo(n))
    return;
  const uchar flagsn = flags[n];
  const uchar flagsn_bo = flagsn & TYPE_BO, flagsn_su = flagsn & TYPE_SU;
  if (flagsn_bo == TYPE_S || flagsn_su == TYPE_G)
    return;
  uxx j[def_velocity_set];
  neighbors(n, j);
  float fhn[def_velocity_set];
  load_f(n, fhn, fi, j, t);
  float fon[def_velocity_set];
  fon[0] = fhn[0];
  load_f_outgoing(n, fon, fi, j, t);
  float massn = mass[n];
  for (uint i = 1u; i < def_velocity_set; i++) {
    massn += massex[j[i]];
  }
  if (flagsn_su == TYPE_F) {
    for (uint i = 1u; i < def_velocity_set; i++)
      massn += fhn[i] - fon[i];
  } else if (flagsn_su == TYPE_I) {
    float phij[def_velocity_set];
    for (uint i = 1u; i < def_velocity_set; i++)
      phij[i] = phi[j[i]];
    float rhon, uxn, uyn, uzn, rho_laplace = 0.0f;
#ifndef EQUILIBRIUM_BOUNDARIES
    calculate_rho_u(fon, &rhon, &uxn, &uyn, &uzn);
#else
    if (flagsn_bo == TYPE_E) {
      rhon = rho[n];
      uxn = u[n];
      uyn = u[def_N + (ulong)n];
      uzn = u[2ul * def_N + (ulong)n];
    } else {
      calculate_rho_u(fon, &rhon, &uxn, &uyn, &uzn);
    }
#endif
    uxn = clamp(uxn, -def_c, def_c);
    uyn = clamp(uyn, -def_c, def_c);
    uzn = clamp(uzn, -def_c, def_c);
    phij[0] = calculate_phi(rhon, massn, flagsn);
    rho_laplace = def_6_sigma == 0.0f
                      ? 0.0f
                      : def_6_sigma * calculate_curvature(n, phij, phi);
    float feg[def_velocity_set];
    const float rho2tmp = 0.5f / rhon;
    const float uxntmp = clamp(fma(fx, rho2tmp, uxn), -def_c, def_c);
    const float uyntmp = clamp(fma(fy, rho2tmp, uyn), -def_c, def_c);
    const float uzntmp = clamp(fma(fz, rho2tmp, uzn), -def_c, def_c);
    calculate_f_eq(1.0f - rho_laplace, uxntmp, uyntmp, uzntmp, feg);
    uchar flagsj_su[def_velocity_set];
    for (uint i = 1u; i < def_velocity_set; i++)
      flagsj_su[i] = flags[j[i]] & TYPE_SU;
    for (uint i = 1u; i < def_velocity_set; i += 2u) {
      massn += flagsj_su[i] & (TYPE_F | TYPE_I)
                   ? flagsj_su[i] == TYPE_F
                         ? fhn[i + 1] - fon[i]
                         : 0.5f * (phij[i] + phij[0]) * (fhn[i + 1] - fon[i])
                   : 0.0f;
      massn +=
          flagsj_su[i + 1u] & (TYPE_F | TYPE_I)
              ? flagsj_su[i + 1u] == TYPE_F
                    ? fhn[i] - fon[i + 1u]
                    : 0.5f * (phij[i + 1u] + phij[0]) * (fhn[i] - fon[i + 1u])
              : 0.0f;
    }
    for (uint i = 1u; i < def_velocity_set; i += 2u) {
      fhn[i] = feg[i + 1u] - fon[i + 1u] + feg[i];
      fhn[i + 1u] = feg[i] - fon[i] + feg[i + 1u];
    }
    store_f_reconstructed(n, fhn, fi, j, t, flagsj_su);
  }
  mass[n] = massn;
}

kernel void surface_1(global uchar *flags) {
  const uxx n = get_global_id(0);
  if (n >= (uxx)def_N)
    return;
  const uchar flagsn_sus = flags[n] & (TYPE_SU | TYPE_S);
  if (flagsn_sus == TYPE_IF) {
    uxx j[def_velocity_set];
    neighbors(n, j);
    for (uint i = 1u; i < def_velocity_set; i++) {
      const uchar flagsji = flags[j[i]];
      const uchar flagsji_su = flagsji & (TYPE_SU | TYPE_S);
      const uchar flagsji_r = flagsji & ~TYPE_SU;
      if (flagsji_su == TYPE_IG)
        flags[j[i]] = flagsji_r | TYPE_I;
      else if (flagsji_su == TYPE_G)
        flags[j[i]] = flagsji_r | TYPE_GI;
    }
  }
}

kernel void surface_2(global fpxx *fi, const global float *rho,
                      const global float *u, global uchar *flags,
                      const ulong t) {
  const uxx n = get_global_id(0);
  if (n >= (uxx)def_N)
    return;
  const uchar flagsn_sus = flags[n] & (TYPE_SU | TYPE_S);
  if (flagsn_sus == TYPE_GI) {
    float rhon, uxn, uyn, uzn;
    average_neighbors_non_gas(n, rho, u, flags, &rhon, &uxn, &uyn, &uzn);
    float feq[def_velocity_set];
    calculate_f_eq(rhon, uxn, uyn, uzn, feq);
    uxx j[def_velocity_set];
    neighbors(n, j);
    store_f(n, feq, fi, j, t);
  } else if (flagsn_sus == TYPE_IG) {
    uxx j[def_velocity_set];
    neighbors(n, j);
    for (uint i = 1u; i < def_velocity_set; i++) {
      const uchar flagsji = flags[j[i]];
      const uchar flagsji_su = flagsji & (TYPE_SU | TYPE_S);
      const uchar flagsji_r = flagsji & ~TYPE_SU;
      if (flagsji_su == TYPE_F || flagsji_su == TYPE_IF) {
        flags[j[i]] = flagsji_r | TYPE_I;
      }
    }
  }
}

kernel void surface_3(const global float *rho, global uchar *flags,
                      global float *mass, global float *massex,
                      global float *phi) {
  const uxx n = get_global_id(0);
  if (n >= (uxx)def_N || is_halo(n))
    return;
  const uchar flagsn_sus = flags[n] & (TYPE_SU | TYPE_S);
  if (flagsn_sus & TYPE_S)
    return;
  const float rhon = rho[n];
  float massn = mass[n];
  float massexn = 0.0f;
  float phin = 0.0f;
  if (flagsn_sus == TYPE_F) {
    massexn = massn - rhon;
    massn = rhon;
    phin = 1.0f;
  } else if (flagsn_sus == TYPE_I) {
    massexn = massn > rhon ? massn - rhon : massn < 0.0f ? massn : 0.0f;
    massn = clamp(massn, 0.0f, rhon);
    phin = calculate_phi(rhon, massn, TYPE_I);
  } else if (flagsn_sus == TYPE_G) {
    massexn = massn;
    massn = 0.0f;
    phin = 0.0f;
  } else if (flagsn_sus == TYPE_IF) {
    flags[n] = (flags[n] & ~TYPE_SU) | TYPE_F;
    massexn = massn - rhon;
    massn = rhon;
    phin = 1.0f;
  } else if (flagsn_sus == TYPE_IG) {
    flags[n] = (flags[n] & ~TYPE_SU) | TYPE_G;
    massexn = massn;
    massn = 0.0f;
    phin = 0.0f;
  } else if (flagsn_sus == TYPE_GI) {
    flags[n] = (flags[n] & ~TYPE_SU) | TYPE_I;
    massexn = massn > rhon ? massn - rhon : massn < 0.0f ? massn : 0.0f;
    massn = clamp(massn, 0.0f, rhon);
    phin = calculate_phi(rhon, massn, TYPE_I);
  }
  uxx j[def_velocity_set];
  neighbors(n, j);
  uint counter = 0u;
  for (uint i = 1u; i < def_velocity_set; i++) {
    const uchar flagsji_su = flags[j[i]] & (TYPE_SU | TYPE_S);
    counter += (uint)(flagsji_su == TYPE_F || flagsji_su == TYPE_I ||
                      flagsji_su == TYPE_IF || flagsji_su == TYPE_GI);
  }
  massn += counter > 0u ? 0.0f : massexn;
  massexn = counter > 0u ? massexn / (float)counter : 0.0f;
  mass[n] = massn;
  massex[n] = massexn;
  phi[n] = phin;
}
#endif

kernel void update_fields(const global fpxx *fi, global float *rho,
                          global float *u, const global uchar *flags,
                          const ulong t, const float fx, const float fy,
                          const float fz
#ifdef FORCE_FIELD
                          ,
                          const global float *F
#endif

#ifdef TEMPERATURE
                          ,
                          const global fpxx *gi, global float *T
#endif

) {
  const uxx n = get_global_id(0);
  if (n >= (uxx)def_N || is_halo(n))
    return;
  const uchar flagsn = flags[n];
  const uchar flagsn_bo = flagsn & TYPE_BO, flagsn_su = flagsn & TYPE_SU;
  if (flagsn_bo == TYPE_S || flagsn_su == TYPE_G)
    return;
  uxx j[def_velocity_set];
  neighbors(n, j);
  float fhn[def_velocity_set];
  load_f(n, fhn, fi, j, t);
#ifdef MOVING_BOUNDARIES
  if (flagsn_bo == TYPE_MS)
    apply_moving_boundaries(fhn, j, u, flags);
#endif
  float rhon, uxn, uyn, uzn;
  calculate_rho_u(fhn, &rhon, &uxn, &uyn, &uzn);
  float fxn = fx, fyn = fy, fzn = fz;
#ifdef FORCE_FIELD
  {
    fxn += F[n];
    fyn += F[def_N + (ulong)n];
    fzn += F[2ul * def_N + (ulong)n];
  }
#endif

#ifdef TEMPERATURE
  {
    uxx j7[7];
    neighbors_temperature(n, j7);
    float ghn[7];
    load_g(n, ghn, gi, j7, t);
    float Tn;
    if (flagsn & TYPE_T) {
      Tn = T[n];
    } else {
      Tn = 0.0f;
      for (uint i = 0u; i < 7u; i++)
        Tn += ghn[i];
      Tn += 1.0f;
      T[n] = Tn;
    }
    fxn -= fx * def_beta * (Tn - def_T_avg);
    fyn -= fy * def_beta * (Tn - def_T_avg);
    fzn -= fz * def_beta * (Tn - def_T_avg);
  }
#endif
  {
#ifdef VOLUME_FORCE
    const float rho2 = 0.5f / rhon;
    uxn = clamp(fma(fxn, rho2, uxn), -def_c, def_c);
    uyn = clamp(fma(fyn, rho2, uyn), -def_c, def_c);
    uzn = clamp(fma(fzn, rho2, uzn), -def_c, def_c);
#else
    uxn = clamp(uxn, -def_c, def_c);
    uyn = clamp(uyn, -def_c, def_c);
    uzn = clamp(uzn, -def_c, def_c);
#endif
  }
#ifndef EQUILIBRIUM_BOUNDARIES
  rho[n] = rhon;
  u[n] = uxn;
  u[def_N + (ulong)n] = uyn;
  u[2ul * def_N + (ulong)n] = uzn;
#else
  if (flagsn_bo != TYPE_E) {
    rho[n] = rhon;
    u[n] = uxn;
    u[def_N + (ulong)n] = uyn;
    u[2ul * def_N + (ulong)n] = uzn;
  }
#endif
}
#ifdef FORCE_FIELD

kernel void update_force_field(const global fpxx *fi, const global uchar *flags,
                               const ulong t, global float *F) {
  const uxx n = get_global_id(0);
  if (n >= (uxx)def_N || is_halo(n))
    return;
  if ((flags[n] & TYPE_BO) != TYPE_S)
    return;
  uxx j[def_velocity_set];
  neighbors(n, j);
  float fhn[def_velocity_set];
  load_f(n, fhn, fi, j, t);
  float Fb = 1.0f, fx = 0.0f, fy = 0.0f, fz = 0.0f;
  calculate_rho_u(fhn, &Fb, &fx, &fy, &fz);
  F[n] = 2.0f * fx * Fb;
  F[def_N + (ulong)n] = 2.0f * fy * Fb;
  F[2ul * def_N + (ulong)n] = 2.0f * fz * Fb;
}

kernel void reset_force_field(global float *F) {
  const uxx n = get_global_id(0);
  if (n >= (uxx)def_N)
    return;
  F[n] = 0.0f;
  F[def_N + (ulong)n] = 0.0f;
  F[2ul * def_N + (ulong)n] = 0.0f;
}

void atomic_add_f(volatile global float *addr, const float val) {
#if cl_nv_compute_capability >= 20
  float ret;
  asm volatile("atom.global.add.f32	%0,[%1],%2;"
               : "=f"(ret)
               : "l"(addr), "f"(val)
               : "memory");

#elif defined(__opencl_c_ext_fp32_global_atomic_add)
  atomic_fetch_add_explicit((volatile global atomic_float *)addr, val,
                            memory_order_relaxed);
#elif __has_builtin(__builtin_amdgcn_global_atomic_fadd_f32)
  __builtin_amdgcn_global_atomic_fadd_f32(addr, val);
#else
  float old = val;
  while ((old = atomic_xchg(addr, atomic_xchg(addr, 0.0f) + old)) != 0.0f)
    ;
#endif
}

kernel void object_center_of_mass(const global uchar *flags,
                                  const uchar flag_marker,
                                  volatile global float *object_sum) {
  const uxx n = get_global_id(0);
  const uint lid = get_local_id(0);
  local float3 cache[cl_workgroup_size];
  local uint cells[cl_workgroup_size];
  const uint is_part_of_object =
      (uint)(n < (uxx)def_N && flags[n] == flag_marker);
  cache[lid] =
      is_part_of_object ? position(coordinates(n)) : (float3)(0.0f, 0.0f, 0.0f);
  cells[lid] = is_part_of_object;
  barrier(CLK_GLOBAL_MEM_FENCE);
  for (uint s = 1u; s < cl_workgroup_size; s *= 2u) {
    if (lid % (2u * s) == 0u) {
      cache[lid] += cache[lid + s];
      cells[lid] += cells[lid + s];
    }
    barrier(CLK_LOCAL_MEM_FENCE);
  }
  const uint local_cells = cells[0];
  if (lid == 0u && local_cells > 0u) {
    const float3 local_sum = cache[0];
    atomic_add_f(&object_sum[0], local_sum.x);
    atomic_add_f(&object_sum[1], local_sum.y);
    atomic_add_f(&object_sum[2], local_sum.z);
    atomic_add((volatile global uint *)&object_sum[3], local_cells);
  }
}

kernel void object_force(const global float *F, const global uchar *flags,
                         const uchar flag_marker,
                         volatile global float *object_sum) {
  const uxx n = get_global_id(0);
  const uint lid = get_local_id(0);
  local float3 cache[cl_workgroup_size];
  cache[lid] = n < (uxx)def_N && flags[n] == flag_marker
                   ? load3(n, F)
                   : (float3)(0.0f, 0.0f, 0.0f);
  barrier(CLK_GLOBAL_MEM_FENCE);
  for (uint s = 1u; s < cl_workgroup_size; s *= 2u) {
    if (lid % (2u * s) == 0u)
      cache[lid] += cache[lid + s];
    barrier(CLK_LOCAL_MEM_FENCE);
  }
  if (lid == 0u) {
    const float3 local_sum = cache[0];
    if (local_sum.x != 0.0f)
      atomic_add_f(&object_sum[0], local_sum.x);
    if (local_sum.y != 0.0f)
      atomic_add_f(&object_sum[1], local_sum.y);
    if (local_sum.z != 0.0f)
      atomic_add_f(&object_sum[2], local_sum.z);
  }
}

kernel void object_torque(const global float *F, const global uchar *flags,
                          const uchar flag_marker, const float cx,
                          const float cy, const float cz,
                          volatile global float *object_sum) {
  const uxx n = get_global_id(0);
  const uint lid = get_local_id(0);
  local float3 cache[cl_workgroup_size];
  cache[lid] =
      n < (uxx)def_N && flags[n] == flag_marker
          ? cross(position(coordinates(n)) - (float3)(cx, cy, cz), load3(n, F))
          : (float3)(0.0f, 0.0f, 0.0f);
  barrier(CLK_GLOBAL_MEM_FENCE);
  for (uint s = 1u; s < cl_workgroup_size; s *= 2u) {
    if (lid % (2u * s) == 0u)
      cache[lid] += cache[lid + s];
    barrier(CLK_LOCAL_MEM_FENCE);
  }
  if (lid == 0u) {
    const float3 local_sum = cache[0];
    if (local_sum.x != 0.0f)
      atomic_add_f(&object_sum[0], local_sum.x);
    if (local_sum.y != 0.0f)
      atomic_add_f(&object_sum[1], local_sum.y);
    if (local_sum.z != 0.0f)
      atomic_add_f(&object_sum[2], local_sum.z);
  }
}
#endif

#ifdef PARTICLES

#ifdef FORCE_FIELD

void spread_force(volatile global float *F, const float3 p, const float3 Fn) {
  const float xa = p.x - 0.5f + 1.5f * (float)def_Nx,
              ya = p.y - 0.5f + 1.5f * (float)def_Ny,
              za = p.z - 0.5f + 1.5f * (float)def_Nz;
  const uint xb = (uint)xa, yb = (uint)ya, zb = (uint)za;
  const float x1 = xa - (float)xb, y1 = ya - (float)yb, z1 = za - (float)zb;
  for (uint c = 0u; c < 8u; c++) {
    const uint i = (c & 0x04u) >> 2, j = (c & 0x02u) >> 1, k = c & 0x01u;
    const uint x = (xb + i) % def_Nx, y = (yb + j) % def_Ny,
               z = (zb + k) % def_Nz;
    const uxx n = (uxx)x + (uxx)(y + z * def_Ny) * (uxx)def_Nx;
    const float d = (1.0f - fabs(x1 - (float)i)) *
                    (1.0f - fabs(y1 - (float)j)) * (1.0f - fabs(z1 - (float)k));
    atomic_add_f(&F[n], Fn.x * d);
    atomic_add_f(&F[def_N + (ulong)n], Fn.y * d);
    atomic_add_f(&F[2ul * def_N + (ulong)n], Fn.z * d);
  }
}
#endif

float3 particle_boundary_force(const float3 p, const global uchar *flags) {
  const float xa = p.x - 0.5f + 1.5f * (float)def_Nx,
              ya = p.y - 0.5f + 1.5f * (float)def_Ny,
              za = p.z - 0.5f + 1.5f * (float)def_Nz;
  const uint xb = (uint)xa, yb = (uint)ya, zb = (uint)za;
  const float x1 = xa - (float)xb, y1 = ya - (float)yb, z1 = za - (float)zb;
  float3 boundary_force = (float3)(0.0f, 0.0f, 0.0f);
  float boundary_distance = 2.0f;
  for (uint c = 0u; c < 8u; c++) {
    const uint i = (c & 0x04u) >> 2, j = (c & 0x02u) >> 1, k = c & 0x01u;
    const uint x = (xb + i) % def_Nx, y = (yb + j) % def_Ny,
               z = (zb + k) % def_Nz;
    const uxx n = (uxx)x + (uxx)(y + z * def_Ny) * (uxx)def_Nx;
    if (flags[n] & (TYPE_S | TYPE_G)) {
      boundary_force +=
          (float3)(0.5f, 0.5f, 0.5f) - (float3)((float)i, (float)j, (float)k);
      boundary_distance = fmin(boundary_distance,
                               length((float3)(x1, y1, z1) -
                                      (float3)((float)i, (float)j, (float)k)));
    }
  }
  const float particle_radius = 0.5f;
  return boundary_distance - 0.5f < particle_radius
             ? normalize(boundary_force)
             : (float3)(0.0f, 0.0f, 0.0f);
}

kernel void integrate_particles(global float *particles, const global float *u,
                                const global uchar *flags,
                                const float time_step_multiplicator
#ifdef FORCE_FIELD
                                ,
                                volatile global float *F, const float fx,
                                const float fy, const float fz
#endif

) {
  const uxx n = get_global_id(0);
  if (n >= (uxx)def_particles_N)
    return;
  const float3 p0 =
      (float3)(particles[n], particles[def_particles_N + (ulong)n],
               particles[2ul * def_particles_N + (ulong)n]);
#ifdef FORCE_FIELD
  if (def_particles_rho != 1.0f) {
    const float drho = def_particles_rho - 1.0f;
    float3 Fn = (float3)(fx * drho, fy * drho, fz * drho);
    spread_force(F, p0, Fn);
  }
#endif
  const float3 p0_mirrored = mirror_position(p0);
  float3 un = interpolate_u(p0_mirrored, u);
  un = (un + length(un) * particle_boundary_force(p0_mirrored, flags)) *
       time_step_multiplicator;
  const float3 p = mirror_position(p0 + un);
  particles[n] = p.x;
  particles[def_particles_N + (ulong)n] = p.y;
  particles[2ul * def_particles_N + (ulong)n] = p.z;
}
#endif

uint get_area(const uint direction) {
  const uint A[3] = {def_Ax, def_Ay, def_Az};
  return A[direction];
}

uxx index_extract_p(const uint a, const uint direction) {
  const uint3 coordinates[3] = {(uint3)(def_Nx - 2u, a % def_Ny, a / def_Ny),
                                (uint3)(a / def_Nz, def_Ny - 2u, a % def_Nz),
                                (uint3)(a % def_Nx, a / def_Nx, def_Nz - 2u)};
  return index(coordinates[direction]);
}

uxx index_extract_m(const uint a, const uint direction) {
  const uint3 coordinates[3] = {(uint3)(1u, a % def_Ny, a / def_Ny),
                                (uint3)(a / def_Nz, 1u, a % def_Nz),
                                (uint3)(a % def_Nx, a / def_Nx, 1u)};
  return index(coordinates[direction]);
}

uxx index_insert_p(const uint a, const uint direction) {
  const uint3 coordinates[3] = {(uint3)(def_Nx - 1u, a % def_Ny, a / def_Ny),
                                (uint3)(a / def_Nz, def_Ny - 1u, a % def_Nz),
                                (uint3)(a % def_Nx, a / def_Nx, def_Nz - 1u)};
  return index(coordinates[direction]);
}

uxx index_insert_m(const uint a, const uint direction) {
  const uint3 coordinates[3] = {(uint3)(0u, a % def_Ny, a / def_Ny),
                                (uint3)(a / def_Nz, 0u, a % def_Nz),
                                (uint3)(a % def_Nx, a / def_Nx, 0u)};
  return index(coordinates[direction]);
}

uint index_transfer(const uint side_i) {
  const uchar index_transfer_data[2u * def_dimensions * def_transfers] = {
#if defined(D2Q9)
      1, 5, 7, 2, 6, 8, 3,
      5, 8, 4, 6, 7
#elif defined(D3Q15)
      1, 7,  14, 9,  11, 2, 8,  13, 10, 12, 3, 7, 12, 9, 13, 4,
      8, 11, 10, 14, 5,  7, 10, 11, 13, 6,  8, 9, 12, 14
#elif defined(D3Q19)
      1, 7,  13, 9,  15, 2, 8,  14, 10, 16, 3,  7,  14, 11, 17, 4,
      8, 13, 12, 18, 5,  9, 16, 11, 18, 6,  10, 15, 12, 17
#elif defined(D3Q27)
      1,  7,  13, 9,  15, 19, 26, 21, 23, 2,  8,  14, 10, 16, 20, 25, 22, 24, 3,
      7,  14, 11, 17, 19, 24, 21, 25, 4,  8,  13, 12, 18, 20, 23, 22, 26, 5,  9,
      16, 11, 18, 19, 22, 23, 25, 6,  10, 15, 12, 17, 20, 21, 24, 26
#endif
  };
  return (uint)index_transfer_data[side_i];
}

void extract_fi(const uint a, const uint A, const uxx n, const uint side,
                const ulong t, global fpxx_copy *transfer_buffer,
                const global fpxx_copy *fi) {
  uxx j[def_velocity_set];
  neighbors(n, j);
  for (uint b = 0u; b < def_transfers; b++) {
    const uint i = index_transfer(side * def_transfers + b);
    const ulong index =
        index_f(i % 2u ? j[i] : n, t % 2ul ? (i % 2u ? i + 1u : i - 1u) : i);
    transfer_buffer[b * A + a] = fi[index];
  }
}

void insert_fi(const uint a, const uint A, const uxx n, const uint side,
               const ulong t, const global fpxx_copy *transfer_buffer,
               global fpxx_copy *fi) {
  uxx j[def_velocity_set];
  neighbors(n, j);
  for (uint b = 0u; b < def_transfers; b++) {
    const uint i = index_transfer(side * def_transfers + b);
    const ulong index = index_f(i % 2u ? n : j[i - 1u],
                                t % 2ul ? i : (i % 2u ? i + 1u : i - 1u));
    fi[index] = transfer_buffer[b * A + a];
  }
}

kernel void transfer_extract_fi(const uint direction, const ulong t,
                                global fpxx_copy *transfer_buffer_p,
                                global fpxx_copy *transfer_buffer_m,
                                const global fpxx_copy *fi) {
  const uint a = get_global_id(0), A = get_area(direction);
  if (a >= A)
    return;
  extract_fi(a, A, index_extract_p(a, direction), 2u * direction + 0u, t,
             transfer_buffer_p, fi);
  extract_fi(a, A, index_extract_m(a, direction), 2u * direction + 1u, t,
             transfer_buffer_m, fi);
}

kernel void transfer__insert_fi(const uint direction, const ulong t,
                                const global fpxx_copy *transfer_buffer_p,
                                const global fpxx_copy *transfer_buffer_m,
                                global fpxx_copy *fi) {
  const uint a = get_global_id(0), A = get_area(direction);
  if (a >= A)
    return;
  insert_fi(a, A, index_insert_p(a, direction), 2u * direction + 0u, t,
            transfer_buffer_p, fi);
  insert_fi(a, A, index_insert_m(a, direction), 2u * direction + 1u, t,
            transfer_buffer_m, fi);
}

void extract_rho_u_flags(const uint a, const uint A, const uxx n,
                         global char *transfer_buffer, const global float *rho,
                         const global float *u, const global uchar *flags) {
  ((global float *)transfer_buffer)[a] = rho[n];
  ((global float *)transfer_buffer)[A + a] = u[n];
  ((global float *)transfer_buffer)[2u * A + a] = u[def_N + (ulong)n];
  ((global float *)transfer_buffer)[3u * A + a] = u[2ul * def_N + (ulong)n];
  ((global uchar *)transfer_buffer)[16u * A + a] = flags[n];
}

void insert_rho_u_flags(const uint a, const uint A, const uxx n,
                        const global char *transfer_buffer, global float *rho,
                        global float *u, global uchar *flags) {
  rho[n] = ((const global float *)transfer_buffer)[a];
  u[n] = ((const global float *)transfer_buffer)[A + a];
  u[def_N + (ulong)n] = ((const global float *)transfer_buffer)[2u * A + a];
  u[2ul * def_N + (ulong)n] =
      ((const global float *)transfer_buffer)[3u * A + a];
  flags[n] = ((const global uchar *)transfer_buffer)[16u * A + a];
}

kernel void transfer_extract_rho_u_flags(const uint direction, const ulong t,
                                         global char *transfer_buffer_p,
                                         global char *transfer_buffer_m,
                                         const global float *rho,
                                         const global float *u,
                                         const global uchar *flags) {
  const uint a = get_global_id(0), A = get_area(direction);
  if (a >= A)
    return;
  extract_rho_u_flags(a, A, index_extract_p(a, direction), transfer_buffer_p,
                      rho, u, flags);
  extract_rho_u_flags(a, A, index_extract_m(a, direction), transfer_buffer_m,
                      rho, u, flags);
}

kernel void transfer__insert_rho_u_flags(const uint direction, const ulong t,
                                         const global char *transfer_buffer_p,
                                         const global char *transfer_buffer_m,
                                         global float *rho, global float *u,
                                         global uchar *flags) {
  const uint a = get_global_id(0), A = get_area(direction);
  if (a >= A)
    return;
  insert_rho_u_flags(a, A, index_insert_p(a, direction), transfer_buffer_p, rho,
                     u, flags);
  insert_rho_u_flags(a, A, index_insert_m(a, direction), transfer_buffer_m, rho,
                     u, flags);
}

kernel void transfer_extract_flags(const uint direction, const ulong t,
                                   global uchar *transfer_buffer_p,
                                   global uchar *transfer_buffer_m,
                                   const global uchar *flags) {
  const uint a = get_global_id(0), A = get_area(direction);
  if (a >= A)
    return;
  transfer_buffer_p[a] = flags[index_extract_p(a, direction)];
  transfer_buffer_m[a] = flags[index_extract_m(a, direction)];
}

kernel void transfer__insert_flags(const uint direction, const ulong t,
                                   const global uchar *transfer_buffer_p,
                                   const global uchar *transfer_buffer_m,
                                   global uchar *flags) {
  const uint a = get_global_id(0), A = get_area(direction);
  if (a >= A)
    return;
  flags[index_insert_p(a, direction)] = transfer_buffer_p[a];
  flags[index_insert_m(a, direction)] = transfer_buffer_m[a];
}
#ifdef SURFACE

void extract_phi_massex_flags(const uint a, const uint A, const uxx n,
                              global char *transfer_buffer,
                              const global float *phi,
                              const global float *massex,
                              const global uchar *flags) {
  ((global float *)transfer_buffer)[a] = phi[n];
  ((global float *)transfer_buffer)[A + a] = massex[n];
  ((global uchar *)transfer_buffer)[8u * A + a] = flags[n];
}

void insert_phi_massex_flags(const uint a, const uint A, const uxx n,
                             const global char *transfer_buffer,
                             global float *phi, global float *massex,
                             global uchar *flags) {
  phi[n] = ((global float *)transfer_buffer)[a];
  massex[n] = ((global float *)transfer_buffer)[A + a];
  flags[n] = ((global uchar *)transfer_buffer)[8u * A + a];
}

kernel void transfer_extract_phi_massex_flags(
    const uint direction, const ulong t, global char *transfer_buffer_p,
    global char *transfer_buffer_m, const global float *phi,
    const global float *massex, const global uchar *flags) {
  const uint a = get_global_id(0), A = get_area(direction);
  if (a >= A)
    return;
  extract_phi_massex_flags(a, A, index_extract_p(a, direction),
                           transfer_buffer_p, phi, massex, flags);
  extract_phi_massex_flags(a, A, index_extract_m(a, direction),
                           transfer_buffer_m, phi, massex, flags);
}

kernel void transfer__insert_phi_massex_flags(
    const uint direction, const ulong t, const global char *transfer_buffer_p,
    const global char *transfer_buffer_m, global float *phi,
    global float *massex, global uchar *flags) {
  const uint a = get_global_id(0), A = get_area(direction);
  if (a >= A)
    return;
  insert_phi_massex_flags(a, A, index_insert_p(a, direction), transfer_buffer_p,
                          phi, massex, flags);
  insert_phi_massex_flags(a, A, index_insert_m(a, direction), transfer_buffer_m,
                          phi, massex, flags);
}
#endif

#ifdef TEMPERATURE

void extract_gi(const uint a, const uxx n, const uint side, const ulong t,
                global fpxx_copy *transfer_buffer, const global fpxx_copy *gi) {
  uxx j7[7u];
  neighbors_temperature(n, j7);
  const uint i = side + 1u;
  const ulong index =
      index_f(i % 2u ? j7[i] : n, t % 2ul ? (i % 2u ? i + 1u : i - 1u) : i);
  transfer_buffer[a] = gi[index];
}

void insert_gi(const uint a, const uxx n, const uint side, const ulong t,
               const global fpxx_copy *transfer_buffer, global fpxx_copy *gi) {
  uxx j7[7u];
  neighbors_temperature(n, j7);
  const uint i = side + 1u;
  const ulong index = index_f(i % 2u ? n : j7[i - 1u],
                              t % 2ul ? i : (i % 2u ? i + 1u : i - 1u));
  gi[index] = transfer_buffer[a];
}

kernel void transfer_extract_gi(const uint direction, const ulong t,
                                global fpxx_copy *transfer_buffer_p,
                                global fpxx_copy *transfer_buffer_m,
                                const global fpxx_copy *gi) {
  const uint a = get_global_id(0), A = get_area(direction);
  if (a >= A)
    return;
  extract_gi(a, index_extract_p(a, direction), 2u * direction + 0u, t,
             transfer_buffer_p, gi);
  extract_gi(a, index_extract_m(a, direction), 2u * direction + 1u, t,
             transfer_buffer_m, gi);
}

kernel void transfer__insert_gi(const uint direction, const ulong t,
                                const global fpxx_copy *transfer_buffer_p,
                                const global fpxx_copy *transfer_buffer_m,
                                global fpxx_copy *gi) {
  const uint a = get_global_id(0), A = get_area(direction);
  if (a >= A)
    return;
  insert_gi(a, index_insert_p(a, direction), 2u * direction + 0u, t,
            transfer_buffer_p, gi);
  insert_gi(a, index_insert_m(a, direction), 2u * direction + 1u, t,
            transfer_buffer_m, gi);
}

kernel void transfer_extract_T(const uint direction, const ulong t,
                               global float *transfer_buffer_p,
                               global float *transfer_buffer_m,
                               const global float *T) {
  const uint a = get_global_id(0), A = get_area(direction);
  if (a >= A)
    return;
  transfer_buffer_p[a] = T[index_extract_p(a, direction)];
  transfer_buffer_m[a] = T[index_extract_m(a, direction)];
}

kernel void transfer__insert_T(const uint direction, const ulong t,
                               const global float *transfer_buffer_p,
                               const global float *transfer_buffer_m,
                               global float *T) {
  const uint a = get_global_id(0), A = get_area(direction);
  if (a >= A)
    return;
  T[index_insert_p(a, direction)] = transfer_buffer_p[a];
  T[index_insert_m(a, direction)] = transfer_buffer_m[a];
}
#endif

kernel void voxelize_mesh(const uint direction, global fpxx *fi,
                          global float *u, global uchar *flags, const ulong t,
                          const uchar flag, const global float *p0,
                          const global float *p1, const global float *p2,
                          const global float *bbu
#ifdef SURFACE
                          ,
                          global float *mass, global float *massex
#endif

) {
  const uint a = get_global_id(0), A = get_area(direction);
  if (a >= A)
    return;
  const uint triangle_number = as_uint(bbu[0]);
  const float x0 = bbu[1], y0 = bbu[2], z0 = bbu[3], x1 = bbu[4], y1 = bbu[5],
              z1 = bbu[6];
  const float cx = bbu[7], cy = bbu[8], cz = bbu[9], ux = bbu[10], uy = bbu[11],
              uz = bbu[12], rx = bbu[13], ry = bbu[14], rz = bbu[15];
  const uint3 xyz =
      direction == 0u
          ? (uint3)((uint)clamp((int)x0 - def_Ox, 0, (int)def_Nx - 1),
                    a % def_Ny, a / def_Ny)
      : direction == 1u
          ? (uint3)(a / def_Nz,
                    (uint)clamp((int)y0 - def_Oy, 0, (int)def_Ny - 1),
                    a % def_Nz)
          : (uint3)(a % def_Nx, a / def_Nx,
                    (uint)clamp((int)z0 - def_Oz, 0, (int)def_Nz - 1));
  const float3 offset =
      (float3)(0.5f * (float)((int)def_Nx + 2 * def_Ox) - 0.5f,
               0.5f * (float)((int)def_Ny + 2 * def_Oy) - 0.5f,
               0.5f * (float)((int)def_Nz + 2 * def_Oz) - 0.5f);
  const float3 r_origin = position(xyz) + offset;
  const float3 r_direction =
      (float3)((float)(direction == 0u), (float)(direction == 1u),
               (float)(direction == 2u));
  uint intersections = 0u, intersections_check = 0u;
  ushort distances[64];
  const bool condition =
      direction == 0u ? r_origin.y < y0 || r_origin.z < z0 ||
                            r_origin.y >= y1 || r_origin.z >= z1
      : direction == 1u ? r_origin.x < x0 || r_origin.z < z0 ||
                              r_origin.x >= x1 || r_origin.z >= z1
                        : r_origin.x < x0 || r_origin.y < y0 ||
                              r_origin.x >= x1 || r_origin.y >= y1;
  if (condition)
    return;
  for (uint i = 0u; i < triangle_number; i++) {
    const uint tx = 3u * i, ty = tx + 1u, tz = ty + 1u;
    const float3 p0i = (float3)(p0[tx], p0[ty], p0[tz]);
    const float3 p1i = (float3)(p1[tx], p1[ty], p1[tz]);
    const float3 p2i = (float3)(p2[tx], p2[ty], p2[tz]);
    const float3 u = p1i - p0i, v = p2i - p0i, w = r_origin - p0i,
                 h = cross(r_direction, v), q = cross(w, u);
    const float g = dot(u, h), f = 1.0f / g, s = f * dot(w, h),
                t = f * dot(r_direction, q), d = f * dot(v, q);
    if (g != 0.0f && s >= 0.0f && s < 1.0f && t >= 0.0f && s + t < 1.0f) {
      if (d > 0.0f) {
        if (intersections < 64u && d < 65536.0f)
          distances[intersections] = (ushort)d;
        intersections++;
      } else {
        intersections_check++;
      }
    }
  }
  for (int i = 1; i < (int)intersections; i++) {
    ushort t = distances[i];
    int j = i - 1;
    while (distances[j] > t && j >= 0) {
      distances[j + 1] = distances[j];
      j--;
    }
    distances[j + 1] = t;
  }
  bool inside = (intersections % 2u) && (intersections_check % 2u);
  const bool set_u = sq(ux) + sq(uy) + sq(uz) + sq(rx) + sq(ry) + sq(rz) > 0.0f;
  uint intersection = intersections % 2u != intersections_check % 2u;
  const uint h0 = direction == 0u ? xyz.x : direction == 1u ? xyz.y : xyz.z;
  const uint hmax =
      direction == 0u   ? (uint)clamp((int)x1 - def_Ox, 0, (int)def_Nx)
      : direction == 1u ? (uint)clamp((int)y1 - def_Oy, 0, (int)def_Ny)
                        : (uint)clamp((int)z1 - def_Oz, 0, (int)def_Nz);
  const uint hmesh = h0 + (uint)distances[min(intersections - 1u, 63u)];
  for (uint h = h0; h < hmax; h++) {
    while (intersection < intersections &&
           h > h0 + (uint)distances[min(intersection, 63u)]) {
      inside = !inside;
      intersection++;
    }
    inside = inside && (intersection < intersections && h < hmesh);
    const uxx n =
        index((uint3)(direction == 0u ? h : xyz.x, direction == 1u ? h : xyz.y,
                      direction == 2u ? h : xyz.z));
    uchar flagsn = flags[n];
    const float3 p = position(coordinates(n)) + offset;
    const float3 u_set = (float3)(ux, uy, uz) +
                         cross((float3)(cx, cy, cz) - p, (float3)(rx, ry, rz));
    if (inside) {
      flagsn = (flagsn & ~TYPE_BO) | flag;
      if (set_u) {
        u[n] = u_set.x;
        u[def_N + (ulong)n] = u_set.y;
        u[2ul * def_N + (ulong)n] = u_set.z;
      }
    } else {
      if ((flagsn & TYPE_BO) == TYPE_S) {
        const float3 un =
            (float3)(u[n], u[def_N + (ulong)n], u[2ul * def_N + (ulong)n]);
        if (un.x == u_set.x && un.y == u_set.y && un.z == u_set.z) {
          if (set_u) {
            uxx j[def_velocity_set];
            neighbors(n, j);
            float feq[def_velocity_set];
            calculate_f_eq(1.0f, un.x, un.y, un.z, feq);
            store_f(n, feq, fi, j, t);
          }
          flagsn = (flagsn & TYPE_BO) == TYPE_MS ? flagsn & ~TYPE_MS
                                                 : flagsn & ~flag;
        }
      }
    }
    flags[n] = flagsn;
#ifdef SURFACE
    mass[n] += massex[n];
    massex[n] = 0.0f;
#endif
  }
}

kernel void unvoxelize_mesh(global uchar *flags, const uchar flag, float x0,
                            float y0, float z0, float x1, float y1, float z1) {
  const uxx n = get_global_id(0);
  const float3 p = position(coordinates(n)) +
                   (float3)(0.5f * (float)((int)def_Nx + 2 * def_Ox) - 0.5f,
                            0.5f * (float)((int)def_Ny + 2 * def_Oy) - 0.5f,
                            0.5f * (float)((int)def_Nz + 2 * def_Oz) - 0.5f);
  if (p.x >= x0 - 1.0f && p.y >= y0 - 1.0f && p.z >= z0 - 1.0f &&
      p.x <= x1 + 1.0f && p.y <= y1 + 1.0f && p.z <= z1 + 1.0f)
    flags[n] &= ~flag;
}
#ifdef GRAPHICS

void calculate_j8(const uint3 xyz, uxx *j) {
  const uxx x0 = (uxx)xyz.x;
  const uxx xp = (uxx)(xyz.x + 1u);
  const uxx y0 = (uxx)(xyz.y * def_Nx);
  const uxx yp = (uxx)((xyz.y + 1u) * def_Nx);
  const uxx z0 = (uxx)xyz.z * (uxx)(def_Ny * def_Nx);
  const uxx zp = (uxx)(xyz.z + 1u) * (uxx)(def_Ny * def_Nx);
  j[0] = x0 + y0 + z0;
  j[1] = xp + y0 + z0;
  j[2] = xp + y0 + zp;
  j[3] = x0 + y0 + zp;
  j[4] = x0 + yp + z0;
  j[5] = xp + yp + z0;
  j[6] = xp + yp + zp;
  j[7] = x0 + yp + zp;
}

void calculate_j32(const uint3 xyz, uxx *j) {
  const uxx x0 = (uxx)xyz.x;
  const uxx xp = (uxx)(xyz.x + 1u);
  const uxx y0 = (uxx)(xyz.y * def_Nx);
  const uxx yp = (uxx)((xyz.y + 1u) * def_Nx);
  const uxx z0 = (uxx)xyz.z * (uxx)(def_Ny * def_Nx);
  const uxx zp = (uxx)(xyz.z + 1u) * (uxx)(def_Ny * def_Nx);
  const uxx xq = (uxx)((xyz.x + 2u) % def_Nx);
  const uxx xm = (uxx)((xyz.x + def_Nx - 1u) % def_Nx);
  const uxx yq = (uxx)(((xyz.y + 2u) % def_Ny) * def_Nx);
  const uxx ym = (uxx)(((xyz.y + def_Ny - 1u) % def_Ny) * def_Nx);
  const uxx zq = (uxx)((xyz.z + 2u) % def_Nz) * (uxx)(def_Ny * def_Nx);
  const uxx zm = (uxx)((xyz.z + def_Nz - 1u) % def_Nz) * (uxx)(def_Ny * def_Nx);
  j[0] = x0 + y0 + z0;
  j[1] = xp + y0 + z0;
  j[2] = xp + y0 + zp;
  j[3] = x0 + y0 + zp;
  j[4] = x0 + yp + z0;
  j[5] = xp + yp + z0;
  j[6] = xp + yp + zp;
  j[7] = x0 + yp + zp;
  j[8] = xm + y0 + z0;
  j[9] = x0 + ym + z0;
  j[10] = x0 + y0 + zm;
  j[11] = xq + y0 + z0;
  j[12] = xp + ym + z0;
  j[13] = xp + y0 + zm;
  j[14] = xq + y0 + zp;
  j[15] = xp + ym + zp;
  j[16] = xp + y0 + zq;
  j[17] = xm + y0 + zp;
  j[18] = x0 + ym + zp;
  j[19] = x0 + y0 + zq;
  j[20] = xm + yp + z0;
  j[21] = x0 + yq + z0;
  j[22] = x0 + yp + zm;
  j[23] = xq + yp + z0;
  j[24] = xp + yq + z0;
  j[25] = xp + yp + zm;
  j[26] = xq + yp + zp;
  j[27] = xp + yq + zp;
  j[28] = xp + yp + zq;
  j[29] = xm + yp + zp;
  j[30] = x0 + yq + zp;
  j[31] = x0 + yp + zq;
}
#ifndef FORCE_FIELD

kernel void graphics_flags(const global float *camera, global int *bitmap,
                           global int *zbuffer, const global uchar *flags) {
#else

kernel void graphics_flags(const global float *camera, global int *bitmap,
                           global int *zbuffer, const global uchar *flags,
                           const global float *F) {
#endif
  const uxx n = get_global_id(0);
  if (n >= (uxx)def_N || is_halo(n))
    return;
  const uchar flagsn = flags[n];
  const uchar flagsn_bo = flagsn & TYPE_BO;
  if (flagsn == 0u || flagsn == TYPE_G)
    return;
  float camera_cache[15];
  for (uint i = 0u; i < 15u; i++)
    camera_cache[i] = camera[i];
  const uint3 xyz = coordinates(n);
  const float3 p = position(xyz);
  if (!is_in_camera_frustrum(p, camera_cache))
    return;
  uxx x0, xp, xm, y0, yp, ym, z0, zp, zm;
  calculate_indices(n, &x0, &xp, &xm, &y0, &yp, &ym, &z0, &zp, &zm);
  const int c = flagsn_bo == TYPE_S ? COLOR_S
                : ((flagsn & TYPE_T) && flagsn_bo == TYPE_E)
                    ? color_average(COLOR_T, COLOR_E)
                : ((flagsn & TYPE_T) && flagsn_bo == TYPE_MS)
                    ? color_average(COLOR_T, COLOR_M)
                : flagsn & TYPE_T      ? COLOR_T
                : flagsn_bo == TYPE_E  ? COLOR_E
                : flagsn_bo == TYPE_MS ? COLOR_M
                : flagsn & TYPE_F      ? COLOR_F
                : flagsn & TYPE_I      ? COLOR_I
                : flagsn & TYPE_X      ? COLOR_X
                : flagsn & TYPE_Y      ? COLOR_Y
                                       : COLOR_0;
  uxx t;
  t = xp + y0 + z0;
  const bool not_xp = xyz.x < def_Nx - 1u && flagsn == flags[t] && !is_halo(t);
  t = xm + y0 + z0;
  const bool not_xm = xyz.x > 0u && flagsn == flags[t] && !is_halo(t);
  t = x0 + yp + z0;
  const bool not_yp = xyz.y < def_Ny - 1u && flagsn == flags[t] && !is_halo(t);
  t = x0 + ym + z0;
  const bool not_ym = xyz.y > 0u && flagsn == flags[t] && !is_halo(t);
  t = x0 + y0 + zp;
  const bool not_zp = xyz.z < def_Nz - 1u && flagsn == flags[t] && !is_halo(t);
  t = x0 + y0 + zm;
  const bool not_zm = xyz.z > 0u && flagsn == flags[t] && !is_halo(t);
  const float3 p0 = (float3)(p.x - 0.5f, p.y - 0.5f, p.z - 0.5f);
  const float3 p1 = (float3)(p.x + 0.5f, p.y + 0.5f, p.z + 0.5f);
  const float3 p2 = (float3)(p.x - 0.5f, p.y - 0.5f, p.z + 0.5f);
  const float3 p3 = (float3)(p.x + 0.5f, p.y + 0.5f, p.z - 0.5f);
  const float3 p4 = (float3)(p.x - 0.5f, p.y + 0.5f, p.z - 0.5f);
  const float3 p5 = (float3)(p.x + 0.5f, p.y - 0.5f, p.z + 0.5f);
  const float3 p6 = (float3)(p.x + 0.5f, p.y - 0.5f, p.z - 0.5f);
  const float3 p7 = (float3)(p.x - 0.5f, p.y + 0.5f, p.z + 0.5f);
  if (!(not_xm || not_ym))
    draw_line(p0, p2, c, camera_cache, bitmap, zbuffer);
  if (!(not_xm || not_zm))
    draw_line(p0, p4, c, camera_cache, bitmap, zbuffer);
  if (!(not_ym || not_zm))
    draw_line(p0, p6, c, camera_cache, bitmap, zbuffer);
  if (!(not_xp || not_yp))
    draw_line(p1, p3, c, camera_cache, bitmap, zbuffer);
  if (!(not_xp || not_zp))
    draw_line(p1, p5, c, camera_cache, bitmap, zbuffer);
  if (!(not_yp || not_zp))
    draw_line(p1, p7, c, camera_cache, bitmap, zbuffer);
  if (!(not_ym || not_zp))
    draw_line(p2, p5, c, camera_cache, bitmap, zbuffer);
  if (!(not_xm || not_zp))
    draw_line(p2, p7, c, camera_cache, bitmap, zbuffer);
  if (!(not_yp || not_zm))
    draw_line(p3, p4, c, camera_cache, bitmap, zbuffer);
  if (!(not_xp || not_zm))
    draw_line(p3, p6, c, camera_cache, bitmap, zbuffer);
  if (!(not_xm || not_yp))
    draw_line(p4, p7, c, camera_cache, bitmap, zbuffer);
  if (!(not_xp || not_ym))
    draw_line(p5, p6, c, camera_cache, bitmap, zbuffer);
#ifdef FORCE_FIELD
  if (flagsn_bo == TYPE_S) {
    const float3 Fn = def_scale_F * (float3)(F[n], F[def_N + (ulong)n],
                                             F[2ul * def_N + (ulong)n]);
    const float Fnl = length(Fn);
    if (Fnl > 0.0f) {
      const int c = colorscale_iron(Fnl);
      draw_line(p, p + Fn, c, camera_cache, bitmap, zbuffer);
    }
  }
#endif
}
#ifndef FORCE_FIELD

kernel void graphics_flags_mc(const global float *camera, global int *bitmap,
                              global int *zbuffer, const global uchar *flags) {
#else

kernel void graphics_flags_mc(const global float *camera, global int *bitmap,
                              global int *zbuffer, const global uchar *flags,
                              const global float *F) {
#endif
  const uxx n = get_global_id(0);
  if (n >= (uxx)def_N || is_halo(n))
    return;
  const uint3 xyz = coordinates(n);
  if (xyz.x >= def_Nx - 1u || xyz.y >= def_Ny - 1u || xyz.z >= def_Nz - 1u)
    return;
  float camera_cache[15];
  for (uint i = 0u; i < 15u; i++)
    camera_cache[i] = camera[i];
  const float3 p = position(xyz);
  if (!is_in_camera_frustrum(p, camera_cache))
    return;
  uxx j[8];
  calculate_j8(xyz, j);
  bool v[8];
  for (uint i = 0u; i < 8u; i++)
    v[i] = (flags[j[i]] & TYPE_BO) == TYPE_S;
  float3 triangles[15];
  const uint tn = marching_cubes_halfway(v, triangles);
  if (tn == 0u)
    return;
#ifdef FORCE_FIELD
  float3 Fj[8];
  for (uint i = 0u; i < 8u; i++)
    Fj[i] = v[i] ? load3(j[i], F) : (float3)(0.0f, 0.0f, 0.0f);
#endif
  for (uint i = 0u; i < tn; i++) {
    const float3 p0 = triangles[3u * i];
    const float3 p1 = triangles[3u * i + 1u];
    const float3 p2 = triangles[3u * i + 2u];
    int c0 = 0xDFDFDF, c1 = 0xDFDFDF, c2 = 0xDFDFDF;
#ifdef FORCE_FIELD
    const float3 normal = normalize(cross(p1 - p0, p2 - p0));
    c0 = colorscale_twocolor(0.5f +
                             def_scale_F * dot(trilinear3(p0, Fj), normal));
    c1 = colorscale_twocolor(0.5f +
                             def_scale_F * dot(trilinear3(p1, Fj), normal));
    c2 = colorscale_twocolor(0.5f +
                             def_scale_F * dot(trilinear3(p2, Fj), normal));
#else
    const float3 normal = cross(p1 - p0, p2 - p0);
#endif
    c0 = shading(c0, p + p0, normal, camera_cache);
    c1 = shading(c1, p + p1, normal, camera_cache);
    c2 = shading(c2, p + p2, normal, camera_cache);
    draw_triangle_interpolated(p + p0, p + p1, p + p2, c0, c1, c2, camera_cache,
                               bitmap, zbuffer);
  }
}
#ifndef TEMPERATURE

kernel void graphics_field(const global float *camera, global int *bitmap,
                           global int *zbuffer, const int field_mode,
                           const global float *rho, const global float *u,
                           const global uchar *flags) {
#else

kernel void graphics_field(const global float *camera, global int *bitmap,
                           global int *zbuffer, const int field_mode,
                           const global float *rho, const global float *u,
                           const global uchar *flags, const global float *T) {
#endif
  const uxx n = get_global_id(0);
  if (n >= (uxx)def_N || is_halo(n))
    return;
  const uint3 xyz = coordinates(n);
  float camera_cache[15];
  for (uint i = 0u; i < 15u; i++)
    camera_cache[i] = camera[i];
  const float3 p = position(xyz);
  if (!is_in_camera_frustrum(p, camera_cache))
    return;
#ifndef MOVING_BOUNDARIES
  if (flags[n] & (TYPE_S | TYPE_E | TYPE_I | TYPE_G))
    return;
#else
  if (flags[n] & (TYPE_I | TYPE_G))
    return;
#endif
  const float3 un = load3(n, u);
  const float ul = length(un);
  if (def_scale_u * ul < 0.1f)
    return;
  int c = 0;
  switch (field_mode) {
  case 0:
    c = colorscale_rainbow(def_scale_u * ul);
    break;
  case 1:
    c = colorscale_twocolor(0.5f + def_scale_rho * (rho[n] - 1.0f));
    break;
#ifdef TEMPERATURE
  case 2:
    c = colorscale_iron(0.5f + def_scale_T * (T[n] - def_T_avg));
    break;
#endif
  }
  draw_line(p - (0.5f / ul) * un, p + (0.5f / ul) * un, c, camera_cache, bitmap,
            zbuffer);
}
#ifndef TEMPERATURE

int ray_grid_traverse_sum(const int background_color, const ray r,
                          const uint Nx, const uint Ny, const uint Nz,
                          const int field_mode, const global float *rho,
                          const global float *u, const global uchar *flags) {
#else

int ray_grid_traverse_sum(const int background_color, const ray r,
                          const uint Nx, const uint Ny, const uint Nz,
                          const int field_mode, const global float *rho,
                          const global float *u, const global uchar *flags,
                          const global float *T) {
#endif
  float sum = 0.0f;
  float traversed_cells_weighted = 0.0f;
  uint traversed_cells = 0u;
  const float3 p =
      (float3)(r.origin.x + 0.5f * (float)Nx, r.origin.y + 0.5f * (float)Ny,
               r.origin.z + 0.5f * (float)Nz);
  const int dx = (int)sign(r.direction.x), dy = (int)sign(r.direction.y),
            dz = (int)sign(r.direction.z);
  int3 xyz = (int3)((int)floor(p.x), (int)floor(p.y), (int)floor(p.z));
  const float fxa = p.x - floor(p.x), fya = p.y - floor(p.y),
              fza = p.z - floor(p.z);
  const float tdx = 1.0f / fmax(fabs(r.direction.x), 1E-6f);
  const float tdy = 1.0f / fmax(fabs(r.direction.y), 1E-6f);
  const float tdz = 1.0f / fmax(fabs(r.direction.z), 1E-6f);
  float tmx = tdx * (dx > 0 ? 1.0f - fxa : dx < 0 ? fxa : 0.0f);
  float tmy = tdy * (dy > 0 ? 1.0f - fya : dy < 0 ? fya : 0.0f);
  float tmz = tdz * (dz > 0 ? 1.0f - fza : dz < 0 ? fza : 0.0f);
  int color = 0;
  switch (field_mode) {
  case 0:
    while (traversed_cells < Nx + Ny + Nz) {
      if (tmx < tmy) {
        if (tmx < tmz) {
          xyz.x += dx;
          tmx += tdx;
        } else {
          xyz.z += dz;
          tmz += tdz;
        }
      } else {
        if (tmy < tmz) {
          xyz.y += dy;
          tmy += tdy;
        } else {
          xyz.z += dz;
          tmz += tdz;
        }
      }
      if (xyz.x < 0 || xyz.y < 0 || xyz.z < 0 || xyz.x >= (int)Nx ||
          xyz.y >= (int)Ny || xyz.z >= (int)Nz)
        break;
      const uxx n = index((uint3)((uint)clamp(xyz.x, 0, (int)Nx - 1),
                                  (uint)clamp(xyz.y, 0, (int)Ny - 1),
                                  (uint)clamp(xyz.z, 0, (int)Nz - 1)));
      if (!(flags[n] & (TYPE_S | TYPE_E | TYPE_G))) {
        const float un = length(load3(n, u));
        const float weight = fmin(un, fabs(un - 0.5f / def_scale_u));
        sum = fma(weight, un, sum);
        traversed_cells_weighted += weight;
      }
      traversed_cells++;
    }
    color = colorscale_rainbow(def_scale_u * sum / traversed_cells_weighted);
    traversed_cells_weighted *= 2.0f * def_scale_u;
    break;
  case 1:
    while (traversed_cells < Nx + Ny + Nz) {
      if (tmx < tmy) {
        if (tmx < tmz) {
          xyz.x += dx;
          tmx += tdx;
        } else {
          xyz.z += dz;
          tmz += tdz;
        }
      } else {
        if (tmy < tmz) {
          xyz.y += dy;
          tmy += tdy;
        } else {
          xyz.z += dz;
          tmz += tdz;
        }
      }
      if (xyz.x < 0 || xyz.y < 0 || xyz.z < 0 || xyz.x >= (int)Nx ||
          xyz.y >= (int)Ny || xyz.z >= (int)Nz)
        break;
      const uxx n = index((uint3)((uint)clamp(xyz.x, 0, (int)Nx - 1),
                                  (uint)clamp(xyz.y, 0, (int)Ny - 1),
                                  (uint)clamp(xyz.z, 0, (int)Nz - 1)));
      if (!(flags[n] & (TYPE_S | TYPE_E | TYPE_G))) {
        const float rhon = rho[n];
        const float weight = fabs(rhon - 1.0f);
        sum = fma(weight, rhon, sum);
        traversed_cells_weighted += weight;
      }
      traversed_cells++;
    }
    color = colorscale_twocolor(
        0.5f + def_scale_rho * (sum / traversed_cells_weighted - 1.0f));
    traversed_cells_weighted *= def_scale_rho;
    break;
#ifdef TEMPERATURE
  case 2:
    while (traversed_cells < Nx + Ny + Nz) {
      if (tmx < tmy) {
        if (tmx < tmz) {
          xyz.x += dx;
          tmx += tdx;
        } else {
          xyz.z += dz;
          tmz += tdz;
        }
      } else {
        if (tmy < tmz) {
          xyz.y += dy;
          tmy += tdy;
        } else {
          xyz.z += dz;
          tmz += tdz;
        }
      }
      if (xyz.x < 0 || xyz.y < 0 || xyz.z < 0 || xyz.x >= (int)Nx ||
          xyz.y >= (int)Ny || xyz.z >= (int)Nz)
        break;
      const uxx n = index((uint3)((uint)clamp(xyz.x, 0, (int)Nx - 1),
                                  (uint)clamp(xyz.y, 0, (int)Ny - 1),
                                  (uint)clamp(xyz.z, 0, (int)Nz - 1)));
      if (!(flags[n] & (TYPE_S | TYPE_E | TYPE_G))) {
        const float Tn = T[n];
        const float weight = sq(Tn - def_T_avg);
        sum = fma(weight, Tn, sum);
        traversed_cells_weighted += weight;
      }
      traversed_cells++;
    }
    color = colorscale_iron(
        0.5f + def_scale_T * (sum / traversed_cells_weighted - def_T_avg));
    traversed_cells_weighted *= sq(4.0f * def_scale_T);
    break;
#endif
  }
  const float opacity = clamp(
      (traversed_cells_weighted - 1.0f) / (float)traversed_cells, 0.0f, 1.0f);
  return color_mix(color, background_color, opacity);
}
#ifndef TEMPERATURE

kernel void graphics_field_rt(const global float *camera, global int *bitmap,
                              global int *zbuffer, const int field_mode,
                              const global float *rho, const global float *u,
                              const global uchar *flags) {
#else

kernel void graphics_field_rt(const global float *camera, global int *bitmap,
                              global int *zbuffer, const int field_mode,
                              const global float *rho, const global float *u,
                              const global uchar *flags,
                              const global float *T) {
#endif
  const uint gid = get_global_id(0);
  const uint lid = get_local_id(0);
  const uint lsi = get_local_size(0);
  const uint tile_width = 8u, tile_height = lsi / tile_width,
             tiles_x = def_screen_width / tile_width;
  const int lx = lid % tile_width, ly = lid / tile_width;
  const int tx = (gid / lsi) % tiles_x, ty = (gid / lsi) / tiles_x;
  const int x = tx * tile_width + lx, y = ty * tile_height + ly;
  const uint n = x + y * def_screen_width;
  float camera_cache[15];
  for (uint i = 0u; i < 15u; i++)
    camera_cache[i] = camera[i];
  ray camray = get_camray(x, y, camera_cache);
  const float distance =
      intersect_cuboid(camray, (float3)(0.0f, 0.0f, 0.0f), (float)def_Nx,
                       (float)def_Ny, (float)def_Nz);
  if (distance == -1.0f)
    return;
  camray.origin =
      camray.origin + fmax(distance + 0.005f, 0.005f) * camray.direction;
#ifndef TEMPERATURE
  bitmap[n] = ray_grid_traverse_sum(bitmap[n], camray, def_Nx, def_Ny, def_Nz,
                                    field_mode, rho, u, flags);
#else
  bitmap[n] = ray_grid_traverse_sum(bitmap[n], camray, def_Nx, def_Ny, def_Nz,
                                    field_mode, rho, u, flags, T);
#endif
}
#ifndef TEMPERATURE

kernel void graphics_field_slice(const global float *camera, global int *bitmap,
                                 global int *zbuffer, const int field_mode,
                                 const int slice_mode, const int slice_x,
                                 const int slice_y, const int slice_z,
                                 const global float *rho, const global float *u,
                                 const global uchar *flags) {
#else

kernel void graphics_field_slice(const global float *camera, global int *bitmap,
                                 global int *zbuffer, const int field_mode,
                                 const int slice_mode, const int slice_x,
                                 const int slice_y, const int slice_z,
                                 const global float *rho, const global float *u,
                                 const global uchar *flags,
                                 const global float *T) {
#endif
  const uint a = get_global_id(0);
  const uint direction = (uint)clamp(slice_mode - 1, 0, 2);
  if (a >= get_area(direction) || slice_mode < 1 || slice_mode > 3 ||
      (slice_mode == 1 && (slice_x < 0 || slice_x >= (int)def_Nx)) ||
      (slice_mode == 2 && (slice_y < 0 || slice_y >= (int)def_Ny)) ||
      (slice_mode == 3 && (slice_z < 0 || slice_z >= (int)def_Nz)))
    return;
  uint3 xyz00, xyz01, xyz10, xyz11;
  float3 normal;
  switch (direction) {
  case 0u:
    xyz00 = (uint3)((uint)slice_x, a % def_Ny, a / def_Ny);
    if (xyz00.y >= def_Ny - 1u || xyz00.z >= def_Nz - 1u)
      return;
    xyz01 = xyz00 + (uint3)(0u, 0u, 1u);
    xyz10 = xyz00 + (uint3)(0u, 1u, 0u);
    xyz11 = xyz00 + (uint3)(0u, 1u, 1u);
    normal = (float3)(1.0f, 0.0f, 0.0f);
    break;
  case 1u:
    xyz00 = (uint3)(a / def_Nz, (uint)slice_y, a % def_Nz);
    if (xyz00.x >= def_Nx - 1u || xyz00.z >= def_Nz - 1u)
      return;
    xyz01 = xyz00 + (uint3)(0u, 0u, 1u);
    xyz10 = xyz00 + (uint3)(1u, 0u, 0u);
    xyz11 = xyz00 + (uint3)(1u, 0u, 1u);
    normal = (float3)(0.0f, 1.0f, 0.0f);
    break;
  case 2u:
    xyz00 = (uint3)(a % def_Nx, a / def_Nx, (uint)slice_z);
    if (xyz00.x >= def_Nx - 1u || xyz00.y >= def_Ny - 1u)
      return;
    xyz01 = xyz00 + (uint3)(0u, 1u, 0u);
    xyz10 = xyz00 + (uint3)(1u, 0u, 0u);
    xyz11 = xyz00 + (uint3)(1u, 1u, 0u);
    normal = (float3)(0.0f, 0.0f, 1.0f);
    break;
  }
  const float3 p00 = position(xyz00), p01 = position(xyz01),
               p10 = position(xyz10), p11 = position(xyz11),
               p = 0.25f * (p00 + p01 + p10 + p11);
  float camera_cache[15];
  for (uint i = 0u; i < 15u; i++)
    camera_cache[i] = camera[i];
  if (!is_in_camera_frustrum(p, camera_cache))
    return;
  const uxx n00 = index(xyz00), n01 = index(xyz01), n10 = index(xyz10),
            n11 = index(xyz11);
  bool d00 = true, d01 = true, d10 = true, d11 = true;
#ifdef SURFACE
  d00 = flags[n00] & (TYPE_F | TYPE_I);
  d01 = flags[n01] & (TYPE_F | TYPE_I);
  d10 = flags[n10] & (TYPE_F | TYPE_I);
  d11 = flags[n11] & (TYPE_F | TYPE_I);
  if ((int)d00 + (int)d01 + (int)d10 + (int)d11 < 3)
    return;
#endif
  int c00 = 0, c01 = 0, c10 = 0, c11 = 0;
  switch (field_mode) {
  case 0:
    c00 = colorscale_rainbow(def_scale_u * length(load3(n00, u)));
    c01 = colorscale_rainbow(def_scale_u * length(load3(n01, u)));
    c10 = colorscale_rainbow(def_scale_u * length(load3(n10, u)));
    c11 = colorscale_rainbow(def_scale_u * length(load3(n11, u)));
    break;
  case 1:
    c00 = colorscale_twocolor(0.5f + def_scale_rho * (rho[n00] - 1.0f));
    c01 = colorscale_twocolor(0.5f + def_scale_rho * (rho[n01] - 1.0f));
    c10 = colorscale_twocolor(0.5f + def_scale_rho * (rho[n10] - 1.0f));
    c11 = colorscale_twocolor(0.5f + def_scale_rho * (rho[n11] - 1.0f));
    break;
#ifdef TEMPERATURE
  case 2:
    c00 = colorscale_iron(0.5f + def_scale_T * (T[n00] - def_T_avg));
    c01 = colorscale_iron(0.5f + def_scale_T * (T[n01] - def_T_avg));
    c10 = colorscale_iron(0.5f + def_scale_T * (T[n10] - def_T_avg));
    c11 = colorscale_iron(0.5f + def_scale_T * (T[n11] - def_T_avg));
    break;
#endif
  }
  c00 = shading(c00, p00, normal, camera_cache);
  c01 = shading(c01, p01, normal, camera_cache);
  c10 = shading(c10, p10, normal, camera_cache);
  c11 = shading(c11, p11, normal, camera_cache);
  const int c = color_average(color_average(c00, c11), color_average(c01, c10));
  if (d00 && d01)
    draw_triangle_interpolated(p00, p01, p, c00, c01, c, camera_cache, bitmap,
                               zbuffer);
  if (d01 && d11)
    draw_triangle_interpolated(p01, p11, p, c01, c11, c, camera_cache, bitmap,
                               zbuffer);
  if (d11 && d10)
    draw_triangle_interpolated(p11, p10, p, c11, c10, c, camera_cache, bitmap,
                               zbuffer);
  if (d10 && d00)
    draw_triangle_interpolated(p10, p00, p, c10, c00, c, camera_cache, bitmap,
                               zbuffer);
}
#ifndef TEMPERATURE

kernel void graphics_streamline(const global float *camera, global int *bitmap,
                                global int *zbuffer, const int field_mode,
                                const int slice_mode, const int slice_x,
                                const int slice_y, const int slice_z,
                                const global float *rho, const global float *u,
                                const global uchar *flags) {
#else

kernel void graphics_streamline(const global float *camera, global int *bitmap,
                                global int *zbuffer, const int field_mode,
                                const int slice_mode, const int slice_x,
                                const int slice_y, const int slice_z,
                                const global float *rho, const global float *u,
                                const global uchar *flags,
                                const global float *T) {
#endif
  const uxx n = get_global_id(0);
  const float3 ps = (float3)((float)slice_x + 0.5f - 0.5f * (float)def_Nx,
                             (float)slice_y + 0.5f - 0.5f * (float)def_Ny,
                             (float)slice_z + 0.5f - 0.5f * (float)def_Nz);
#ifndef D2Q9
  if (n >= (uxx)(def_Nx / def_streamline_sparse) *
               (uxx)(def_Ny / def_streamline_sparse) *
               (uxx)(def_Nz / def_streamline_sparse))
    return;
  const uint z = (uint)(n / (uxx)((def_Nx / def_streamline_sparse) *
                                  (def_Ny / def_streamline_sparse)));
  const uint t = (uint)(n % (uxx)((def_Nx / def_streamline_sparse) *
                                  (def_Ny / def_streamline_sparse)));
  const uint y = (uint)(t / (def_Nx / def_streamline_sparse));
  const uint x = (uint)(t % (def_Nx / def_streamline_sparse));
  float3 p = (float)def_streamline_sparse *
                 ((float3)((float)x + 0.5f, (float)y + 0.5f, (float)z + 0.5f)) -
             0.5f * ((float3)((float)def_Nx, (float)def_Ny, (float)def_Nz));
  const bool rx = fabs(p.x - ps.x) > 0.5f * (float)def_streamline_sparse,
             ry = fabs(p.y - ps.y) > 0.5f * (float)def_streamline_sparse,
             rz = fabs(p.z - ps.z) > 0.5f * (float)def_streamline_sparse;
#else
  if (n >= (def_Nx / def_streamline_sparse) * (def_Ny / def_streamline_sparse))
    return;
  const uint y = (uint)(n / (uxx)(def_Nx / def_streamline_sparse));
  const uint x = (uint)(n % (uxx)(def_Nx / def_streamline_sparse));
  float3 p =
      ((float3)((float)def_streamline_sparse * ((float)x + 0.5f),
                (float)def_streamline_sparse * ((float)y + 0.5f), 0.5f)) -
      0.5f * ((float3)((float)def_Nx, (float)def_Ny, (float)def_Nz));
  const bool rx = fabs(p.x - ps.x) > 0.5f * (float)def_streamline_sparse,
             ry = fabs(p.y - ps.y) > 0.5f * (float)def_streamline_sparse,
             rz = true;
#endif
  if ((slice_mode == 1 && rx) || (slice_mode == 2 && ry) ||
      (slice_mode == 3 && rz) || (slice_mode == 4 && rx && rz) ||
      (slice_mode == 5 && rx && ry && rz) || (slice_mode == 6 && ry && rz) ||
      (slice_mode == 7 && rx && ry))
    return;
  if ((slice_mode == 1 || slice_mode == 5 || slice_mode == 4 ||
       slice_mode == 7) &
      !rx)
    p.x = ps.x;
  if ((slice_mode == 2 || slice_mode == 5 || slice_mode == 6 ||
       slice_mode == 7) &
      !ry)
    p.y = ps.y;
  if ((slice_mode == 3 || slice_mode == 5 || slice_mode == 4 ||
       slice_mode == 6) &
      !rz)
    p.z = ps.z;
  float camera_cache[15];
  for (uint i = 0u; i < 15u; i++)
    camera_cache[i] = camera[i];
  const float hLx = 0.5f * (float)(def_Nx - 2u * (def_Dx > 1u)),
              hLy = 0.5f * (float)(def_Ny - 2u * (def_Dy > 1u)),
              hLz = 0.5f * (float)(def_Nz - 2u * (def_Dz > 1u));
  for (float dt = -1.0f; dt <= 1.0f; dt += 2.0f) {
    float3 p0, p1 = p;
    for (uint l = 0u; l < def_streamline_length / 2u; l++) {
      const uint x = (uint)(p1.x + 1.5f * (float)def_Nx) % def_Nx;
      const uint y = (uint)(p1.y + 1.5f * (float)def_Ny) % def_Ny;
      const uint z = (uint)(p1.z + 1.5f * (float)def_Nz) % def_Nz;
      const uxx n = (uxx)x + (uxx)(y + z * def_Ny) * (uxx)def_Nx;
      if (flags[n] & (TYPE_S | TYPE_E | TYPE_I | TYPE_G))
        return;
      const float3 un = load3(n, u);
      const float ul = length(un);
      p0 = p1;
      p1 += (dt / ul) * un;
      if (def_scale_u * ul < 0.1f || p1.x < -hLx || p1.x > hLx || p1.y < -hLy ||
          p1.y > hLy || p1.z < -hLz || p1.z > hLz)
        break;
      int c = 0;
      switch (field_mode) {
      case 0:
        c = colorscale_rainbow(def_scale_u * ul);
        break;
      case 1:
        c = colorscale_twocolor(0.5f + def_scale_rho * (rho[n] - 1.0f));
        break;
#ifdef TEMPERATURE
      case 2:
        c = colorscale_iron(0.5f + def_scale_T * (T[n] - def_T_avg));
        break;
#endif
      }
      draw_line(p0, p1, c, camera_cache, bitmap, zbuffer);
    }
  }
}
#ifndef TEMPERATURE

kernel void graphics_q_field(const global float *camera, global int *bitmap,
                             global int *zbuffer, const int field_mode,
                             const global float *rho, const global float *u,
                             const global uchar *flags) {
#else

kernel void graphics_q_field(const global float *camera, global int *bitmap,
                             global int *zbuffer, const int field_mode,
                             const global float *rho, const global float *u,
                             const global uchar *flags, const global float *T) {
#endif
  const uxx n = get_global_id(0);
  if (n >= (uxx)def_N || is_halo(n))
    return;
  if (flags[n] & (TYPE_S | TYPE_E | TYPE_I | TYPE_G))
    return;
  const float3 p = position(coordinates(n));
  float camera_cache[15];
  for (uint i = 0u; i < 15u; i++)
    camera_cache[i] = camera[i];
  if (!is_in_camera_frustrum(p, camera_cache))
    return;
  float3 un = load3(n, u);
  const float ul = length(un);
  const float Q = calculate_Q(n, u);
  if (Q < def_scale_Q_min || ul == 0.0f)
    return;
  int c = 0;
  switch (field_mode) {
  case 0:
    c = colorscale_rainbow(def_scale_u * ul);
    break;
  case 1:
    c = colorscale_twocolor(0.5f + def_scale_rho * (rho[n] - 1.0f));
    break;
#ifdef TEMPERATURE
  case 2:
    c = colorscale_iron(0.5f + def_scale_T * (T[n] - def_T_avg));
    break;
#endif
  }
  draw_line(p - (0.5f / ul) * un, p + (0.5f / ul) * un, c, camera_cache, bitmap,
            zbuffer);
}

kernel void graphics_q(const global float *camera, global int *bitmap,
                       global int *zbuffer, const int field_mode,
                       const global float *rho, const global float *u
#ifdef SURFACE
                       ,
                       const global uchar *flags
#endif

#ifdef TEMPERATURE
                       ,
                       const global float *T
#endif

) {
  const uxx n = get_global_id(0);
  const uint3 xyz = coordinates(n);
  if (xyz.x >= def_Nx - 1u || xyz.y >= def_Ny - 1u || xyz.z >= def_Nz - 1u ||
      is_halo_q(xyz))
    return;
  const float3 p = position(xyz);
  float camera_cache[15];
  for (uint i = 0u; i < 15u; i++)
    camera_cache[i] = camera[i];
  if (!is_in_camera_frustrum(p, camera_cache))
    return;
  uxx j[32];
  calculate_j32(xyz, j);
#ifdef SURFACE
  uchar flags_cell = 0u;
  for (uint i = 0u; i < 8u; i++)
    flags_cell |= flags[j[i]];
  if (flags_cell & (TYPE_I | TYPE_G))
    return;
#endif
  float3 uj[32];
  for (uint i = 0u; i < 32u; i++)
    uj[i] = load3(j[i], u);
  float v[8];
  v[0] = calculate_Q_cached(uj[1], uj[8], uj[4], uj[9], uj[3], uj[10]);
  v[1] = calculate_Q_cached(uj[11], uj[0], uj[5], uj[12], uj[2], uj[13]);
  v[2] = calculate_Q_cached(uj[14], uj[3], uj[6], uj[15], uj[16], uj[1]);
  v[3] = calculate_Q_cached(uj[2], uj[17], uj[7], uj[18], uj[19], uj[0]);
  v[4] = calculate_Q_cached(uj[5], uj[20], uj[21], uj[0], uj[7], uj[22]);
  v[5] = calculate_Q_cached(uj[23], uj[4], uj[24], uj[1], uj[6], uj[25]);
  v[6] = calculate_Q_cached(uj[26], uj[7], uj[27], uj[2], uj[28], uj[5]);
  v[7] = calculate_Q_cached(uj[6], uj[29], uj[30], uj[3], uj[31], uj[4]);
  float3 triangles[15];
  const uint tn = marching_cubes(v, def_scale_Q_min, triangles);
  if (tn == 0u)
    return;
  for (uint i = 0u; i < tn; i++) {
    const float3 p0 = triangles[3u * i];
    const float3 p1 = triangles[3u * i + 1u];
    const float3 p2 = triangles[3u * i + 2u];
    const float3 normal = cross(p1 - p0, p2 - p0);
    int c0 = 0, c1 = 0, c2 = 0;
    switch (field_mode) {
    case 0:
      c0 = shading(colorscale_rainbow(def_scale_u * length(trilinear3(p0, uj))),
                   p + p0, normal, camera_cache);
      c1 = shading(colorscale_rainbow(def_scale_u * length(trilinear3(p1, uj))),
                   p + p1, normal, camera_cache);
      c2 = shading(colorscale_rainbow(def_scale_u * length(trilinear3(p2, uj))),
                   p + p2, normal, camera_cache);
      break;
    case 1:
      for (uint i = 0u; i < 8u; i++)
        v[i] = rho[j[i]];
      c0 = shading(
          colorscale_twocolor(0.5f + def_scale_rho * (trilinear(p0, v) - 1.0f)),
          p + p0, normal, camera_cache);
      c1 = shading(
          colorscale_twocolor(0.5f + def_scale_rho * (trilinear(p1, v) - 1.0f)),
          p + p1, normal, camera_cache);
      c2 = shading(
          colorscale_twocolor(0.5f + def_scale_rho * (trilinear(p2, v) - 1.0f)),
          p + p2, normal, camera_cache);
      break;
#ifdef TEMPERATURE
    case 2:
      for (uint i = 0u; i < 8u; i++)
        v[i] = T[j[i]];
      c0 = shading(
          colorscale_iron(0.5f + def_scale_T * (trilinear(p0, v) - def_T_avg)),
          p + p0, normal, camera_cache);
      c1 = shading(
          colorscale_iron(0.5f + def_scale_T * (trilinear(p1, v) - def_T_avg)),
          p + p1, normal, camera_cache);
      c2 = shading(
          colorscale_iron(0.5f + def_scale_T * (trilinear(p2, v) - def_T_avg)),
          p + p2, normal, camera_cache);
      break;
#endif
    }
    draw_triangle_interpolated(p + p0, p + p1, p + p2, c0, c1, c2, camera_cache,
                               bitmap, zbuffer);
  }
}
// #ifdef EXPORT_SURFACE

#ifdef SURFACE

kernel void graphics_rasterize_phi(const global float *camera,
                                   global int *bitmap, global int *zbuffer,
                                   const global float *phi) {
  const uxx n = get_global_id(0);
  const uint3 xyz = coordinates(n);
  if (xyz.x >= def_Nx - 1u || xyz.y >= def_Ny - 1u || xyz.z >= def_Nz - 1u)
    return;
  const float3 p = position(xyz);
  float camera_cache[15];
  for (uint i = 0u; i < 15u; i++)
    camera_cache[i] = camera[i];
  if (!is_in_camera_frustrum(p, camera_cache))
    return;
  uxx j[8];
  calculate_j8(xyz, j);
  float v[8];
  for (uint i = 0u; i < 8u; i++)
    v[i] = phi[j[i]];
  float3 triangles[15];
  const uint tn = marching_cubes(v, 0.502f, triangles);
  if (tn == 0u)
    return;
  for (uint i = 0u; i < tn; i++) {
    const float3 p0 = triangles[3u * i];
    const float3 p1 = triangles[3u * i + 1u];
    const float3 p2 = triangles[3u * i + 2u];
    const float3 normal = cross(p1 - p0, p2 - p0);
    const int c0 = shading(0x379BFF, p + p0, normal, camera_cache);
    const int c1 = shading(0x379BFF, p + p1, normal, camera_cache);
    const int c2 = shading(0x379BFF, p + p2, normal, camera_cache);
    draw_triangle_interpolated(p + p0, p + p1, p + p2, c0, c1, c2, camera_cache,
                               bitmap, zbuffer);
  }
}

int raytrace_phi_next_ray(const ray reflection, const ray transmission,
                          const float reflectivity, const float transmissivity,
                          const global float *phi, const global uchar *flags,
                          const global int *skybox) {
  int color_reflect = 0, color_transmit = 0;
  ray reflection_next, transmission_next;
  float reflection_reflectivity, reflection_transmissivity,
      transmission_reflectivity, transmission_transmissivity;
  if (raytrace_phi(reflection, &reflection_next, &transmission_next,
                   &reflection_reflectivity, &reflection_transmissivity, phi,
                   flags, skybox, def_Nx, def_Ny, def_Nz)) {
    color_reflect =
        last_ray(reflection_next, transmission_next, reflection_reflectivity,
                 reflection_transmissivity, skybox);
  } else {
    color_reflect = skybox_color(reflection, skybox);
  }
  if (raytrace_phi(transmission, &reflection_next, &transmission_next,
                   &transmission_reflectivity, &transmission_transmissivity,
                   phi, flags, skybox, def_Nx, def_Ny, def_Nz)) {
    color_transmit =
        last_ray(reflection_next, transmission_next, transmission_reflectivity,
                 transmission_transmissivity, skybox);
  } else {
    color_transmit = skybox_color(transmission, skybox);
  }
  return color_mix(
      color_reflect,
      color_mix(color_transmit, def_absorption_color, transmissivity),
      reflectivity);
}

int raytrace_phi_next_ray_mirror(const ray reflection, const global float *phi,
                                 const global uchar *flags,
                                 const global int *skybox) {
  int color_reflect = 0;
  ray reflection_next;
  if (raytrace_phi_mirror(reflection, &reflection_next, phi, flags, skybox,
                          def_Nx, def_Ny, def_Nz)) {
    color_reflect = skybox_color(reflection_next, skybox);
  } else {
    color_reflect = skybox_color(reflection, skybox);
  }
  return color_reflect;
}

kernel void graphics_raytrace_phi(const global float *camera,
                                  global int *bitmap, const global int *skybox,
                                  const global float *phi,
                                  const global uchar *flags) {
  const uint gid = get_global_id(0);
  const uint lid = get_local_id(0);
  const uint lsi = get_local_size(0);
  const uint tile_width = 8u, tile_height = lsi / tile_width,
             tiles_x = def_screen_width / tile_width;
  const int lx = lid % tile_width, ly = lid / tile_width;
  const int tx = (gid / lsi) % tiles_x, ty = (gid / lsi) / tiles_x;
  const int x = tx * tile_width + lx, y = ty * tile_height + ly;
  const uint n = x + y * def_screen_width;
  float camera_cache[15];
  for (uint i = 0u; i < 15u; i++)
    camera_cache[i] = camera[i];
  ray camray = get_camray(x, y, camera_cache);
  const float distance =
      intersect_cuboid(camray, (float3)(0.0f, 0.0f, 0.0f), (float)def_Nx,
                       (float)def_Ny, (float)def_Nz);
  camray.origin =
      camray.origin + fmax(distance + 0.005f, 0.005f) * camray.direction;
  ray reflection, transmission;
  float reflectivity, transmissivity;
  int pixelcolor = 0;
  if (raytrace_phi(camray, &reflection, &transmission, &reflectivity,
                   &transmissivity, phi, flags, skybox, def_Nx, def_Ny,
                   def_Nz)) {
    pixelcolor = last_ray(reflection, transmission, reflectivity,
                          transmissivity, skybox);
  } else {
    pixelcolor = skybox_color(camray, skybox);
  }
  bitmap[n] = pixelcolor;
}
#endif

#ifdef EXPORT_SURFACE
kernel void count_surface_triangles(const global float *phi, global uint *triangle_count) {
  const uxx n = get_global_id(0);
  if(n >= def_N) return;

  // Get 3D coordinates
  const uint3 xyz = coordinates(n);
  const uint x = xyz.x;
  const uint y = xyz.y;
  const uint z = xyz.z;

  // Skip boundary cells
  if(x >= def_Nx-1u || y >= def_Ny-1u || z >= def_Nz-1u) return;

  // Get indices of 8 cube corners
  const uxx x0 = (uxx)x, xp = (uxx)(x+1u);
  const uxx y0 = (uxx)(y*def_Nx), yp = (uxx)((y+1u)*def_Nx);
  const uxx z0 = (uxx)(z)*(uxx)(def_Ny*def_Nx), zp = (uxx)(z+1u)*(uxx)(def_Ny*def_Nx);

  float v[8];
  v[0] = phi[x0+y0+z0]; v[1] = phi[xp+y0+z0];
  v[2] = phi[xp+y0+zp]; v[3] = phi[x0+y0+zp];
  v[4] = phi[x0+yp+z0]; v[5] = phi[xp+yp+z0];
  v[6] = phi[xp+yp+zp]; v[7] = phi[x0+yp+zp];

  // Check if cube intersects surface
  float3 triangles[15];
  const uint tn = marching_cubes(v, 0.5f, triangles);

  if(tn > 0u) {
    atomic_add(triangle_count, tn);
  }
}

kernel void export_surface(const global float *phi, global float *vertices,
                          global uint *triangle_count, const ulong max_triangles) {
  const uxx n = get_global_id(0);
  if(n >= def_N) return;

  // Get 3D coordinates
  const uint3 xyz = coordinates(n);
  const uint x = xyz.x;
  const uint y = xyz.y;
  const uint z = xyz.z;

  // Skip boundary cells
  if(x >= def_Nx-1u || y >= def_Ny-1u || z >= def_Nz-1u) return;

  // Get indices of 8 cube corners
  const uxx x0 = (uxx)x, xp = (uxx)(x+1u);
  const uxx y0 = (uxx)(y*def_Nx), yp = (uxx)((y+1u)*def_Nx);
  const uxx z0 = (uxx)(z)*(uxx)(def_Ny*def_Nx), zp = (uxx)(z+1u)*(uxx)(def_Ny*def_Nx);

  float v[8];
  v[0] = phi[x0+y0+z0]; v[1] = phi[xp+y0+z0];
  v[2] = phi[xp+y0+zp]; v[3] = phi[x0+y0+zp];
  v[4] = phi[x0+yp+z0]; v[5] = phi[xp+yp+z0];
  v[6] = phi[xp+yp+zp]; v[7] = phi[x0+yp+zp];

  // Get triangles from marching cubes
  float3 triangles[15];
  const uint tn = marching_cubes(v, 0.5f, triangles);

  if(tn > 0u) {
    // Atomically reserve space in output buffer
    const uint base_index = atomic_add(triangle_count, tn);

    // Check buffer overflow
    if(base_index + tn > max_triangles) return;

    // Write triangles to global memory
    const float3 offset = (float3)((float)x, (float)y, (float)z);
    for(uint i = 0u; i < tn; i++) {
      const uint vertex_index = (base_index + i) * 9u;
      const float3 p0 = triangles[3u*i] + offset;
      const float3 p1 = triangles[3u*i+1u] + offset;
      const float3 p2 = triangles[3u*i+2u] + offset;

      // Write triangle vertices (9 floats per triangle)
      vertices[vertex_index+0u] = p0.x;
      vertices[vertex_index+1u] = p0.y;
      vertices[vertex_index+2u] = p0.z;
      vertices[vertex_index+3u] = p1.x;
      vertices[vertex_index+4u] = p1.y;
      vertices[vertex_index+5u] = p1.z;
      vertices[vertex_index+6u] = p2.x;
      vertices[vertex_index+7u] = p2.y;
      vertices[vertex_index+8u] = p2.z;
    }
  }
}
#endif // EXPORT_SURFACE

#ifdef PARTICLES

kernel void graphics_particles(const global float *camera, global int *bitmap,
                               global int *zbuffer,
                               const global float *particles) {
  const uxx n = get_global_id(0);
  if (n >= (uxx)def_particles_N)
    return;
  float camera_cache[15];
  for (uint i = 0u; i < 15u; i++)
    camera_cache[i] = camera[i];
  const int c = COLOR_P;
  const float3 p = (float3)(particles[n], particles[def_particles_N + (ulong)n],
                            particles[2ul * def_particles_N + (ulong)n]);
  draw_point(p, c, camera_cache, bitmap, zbuffer);
}
#endif

#endif
