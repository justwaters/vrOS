#ifndef CARDBOARD_SDK_CARDBOARD_DEVICE_PB_H_
#define CARDBOARD_SDK_CARDBOARD_DEVICE_PB_H_

#include <cstdint>
#include <vector>
#include <cstring>

namespace cardboard {

class DeviceParams {
 public:
  enum VerticalAlignmentType {
    BOTTOM = 0,
    CENTER = 1,
    TOP = 2,
  };

  DeviceParams() { SetDefaults(); }

  void ParseFromArray(const uint8_t* data, int size) {
    if (!data || size <= 0) {
      SetDefaults();
      return;
    }
    ParseProto(data, size);
  }

  float screen_to_lens_distance() const { return screen_to_lens_distance_; }
  float inter_lens_distance() const { return inter_lens_distance_; }
  float tray_to_lens_distance() const { return tray_to_lens_distance_; }
  int vertical_alignment() const { return vertical_alignment_; }
  float distortion_coefficients(int index) const { return distortion_coeffs_[index]; }
  int distortion_coefficients_size() const { return static_cast<int>(distortion_coeffs_.size()); }
  float left_eye_field_of_view_angles(int index) const { return fov_angles_[index]; }

 private:
  void SetDefaults() {
    screen_to_lens_distance_ = 0.042f;
    inter_lens_distance_ = 0.06f;
    tray_to_lens_distance_ = 0.035f;
    vertical_alignment_ = BOTTOM;
    distortion_coeffs_ = {0.441f, 0.156f};
    fov_angles_ = {40.0f, 40.0f, 40.0f, 40.0f};
  }

  static uint64_t ReadVarint(const uint8_t* data, int size, int& offset) {
    uint64_t value = 0;
    int shift = 0;
    while (offset < size) {
      uint8_t byte = data[offset++];
      value |= static_cast<uint64_t>(byte & 0x7F) << shift;
      shift += 7;
      if (!(byte & 0x80)) return value;
    }
    return value;
  }

  void ParseProto(const uint8_t* data, int size) {
    SetDefaults();
    int offset = 0;
    while (offset < size) {
      uint64_t key = ReadVarint(data, size, offset);
      int field_number = static_cast<int>(key >> 3);
      int wire_type = static_cast<int>(key & 0x7);

      switch (wire_type) {
        case 0: {  // Varint
          uint64_t value = ReadVarint(data, size, offset);
          switch (field_number) {
            case 11: vertical_alignment_ = static_cast<int>(value); break;
            case 12: /* primary_button - ignored */ break;
          }
          break;
        }
        case 2: {  // Length-delimited
          int len = static_cast<int>(ReadVarint(data, size, offset));
          if (field_number == 1 || field_number == 2) {
            offset += len;  // vendor/model strings - skip
          } else if (field_number == 5) {  // left_eye_field_of_view_angles (packed)
            int count = len / 4;
            fov_angles_.resize(count);
            for (int i = 0; i < count && offset + 4 <= size; i++) {
              float val;
              std::memcpy(&val, &data[offset], 4);
              fov_angles_[i] = val;
              offset += 4;
            }
          } else if (field_number == 7) {  // distortion_coefficients (packed)
            int count = len / 4;
            distortion_coeffs_.resize(count);
            for (int i = 0; i < count && offset + 4 <= size; i++) {
              float val;
              std::memcpy(&val, &data[offset], 4);
              distortion_coeffs_[i] = val;
              offset += 4;
            }
          } else {
            offset += len;
          }
          break;
        }
        case 5: {  // 32-bit
          if (offset + 4 > size) return;
          float val;
          std::memcpy(&val, &data[offset], 4);
          offset += 4;
          switch (field_number) {
            case 3: screen_to_lens_distance_ = val; break;
            case 4: inter_lens_distance_ = val; break;
            case 6: tray_to_lens_distance_ = val; break;
          }
          break;
        }
        default:
          return;
      }
    }
  }

  float screen_to_lens_distance_;
  float inter_lens_distance_;
  float tray_to_lens_distance_;
  int vertical_alignment_;
  std::vector<float> distortion_coeffs_;
  std::vector<float> fov_angles_;
};

}  // namespace cardboard

#endif  // CARDBOARD_SDK_CARDBOARD_DEVICE_PB_H_
