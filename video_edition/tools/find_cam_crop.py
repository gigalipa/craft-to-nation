from PIL import Image
import numpy as np

im = Image.open('video_edition/media/raw/cam_0120.jpg')
arr = np.array(im)
# Find columns with non-black pixels
col_max = arr.max(axis=(0, 2))
non_zero_cols = np.where(col_max > 20)[0]
print("Non-black column range:", non_zero_cols[0], "to", non_zero_cols[-1])
print("Width of camera feed:", non_zero_cols[-1] - non_zero_cols[0] + 1)
