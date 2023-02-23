
Code by Gino Morilla (2023)

--

Optimizeimages script may optimize images at certain path, stripping metadata, and with an optional resize.

It will make use of following binaries which need to be installed:

- jpegoptim
- optipng
- identify (imagemagick)
- mogrify (imagemagick)
- convert (imagemagick)

How to use it:
  ./optimizeimages.sh -p|--path <path>

Select any of these options:
  -p, --path    <string>        Mandatory! Select path where images are<BR>
  -q, --quality <integer>       Select final quality (DEFAULT: 75%)
  -r, --resize  <integer>       Select maximum size in pixels for the largest side, keeping aspect ratio
  -w, --width   <integer>       Select maximum width in pixels for the images, keeping aspect ratio
  -v, --height  <integer>       Select maximum height in pixels for the images, keeping aspect ratio
  -u, --unsharp                 Unsharp resized/shrinked images by using: -unsharp 1.5x1+0.7+0.02
  -d, --day                     Just to process ONLY recent images (last day images starting at midnight)
  -j, --jpeg                    Process ONLY jpeg files at path
  -x, --png                     Process ONLY pngs files at path
  -h, --help                    Some help here!
