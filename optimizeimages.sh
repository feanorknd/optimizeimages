#!/bin/bash

# VERSION 2. TODA LA PROGRAMACION ESTÁ REALIZADA POR GINO
# -----------------------------------------------------------------------------------------------------------------------------------
# VARIABLES

function showhelp {

echo "
$0 will optimize jpeg|png files at selected path, stripping metadata while resizing or not.

How to use it:
  $0 -p|--path <path>

Select any of these options:
  -p, --path	<string>	Mandatory! Select path where images are
  -q, --quality	<integer>	Select final quality (DEFAULT: 75%)
  -r, --resize	<integer>	Select maximum size in pixels for the largest side, keeping aspect ratio
  -w, --width	<integer>	Select maximum width in pixels for the images, keeping aspect ratio
  -v, --height	<integer>	Select maximum height in pixels for the images, keeping aspect ratio
  -u, --unsharp			Unsharp resized/shrinked images by using: -unsharp 1.5x1+0.7+0.02
  -d, --day			Just to process ONLY recent images (last day images starting at midnight)
  -j, --jpeg            	Process ONLY jpeg files at path
  -x, --png             	Process ONLY pngs files at path
  -h, --help			Some help here!

"
}

if [[ "$#" = 0 ]]; then showhelp; exit 1; fi

function checkarg {
        if [ -z "$2" ]; then
                echo "Error: must specify parameter for $1 function"
                echo ""
                showhelp
                exit 1
        fi
        if [ "$1" == "images" ] && [ ! -d $2 ]; then
                echo "Path do not seem to exist. Exiting..."
                echo ""
                exit 1
        fi
        if [ "$1" == "quality" ] || [ "$1" == "resize" ] || [ "$1" == "width" ] || [ "$1" == "vertical" ] && [[ ! "$2" =~ ^[0-9]+$ ]]; then
                echo "$1 should be an integer number. Exiting..."
                echo ""
                exit 1
        fi
}

while [[ "$#" > 0 ]]; do
  case "$1" in
    -p|--path)		checkarg "images" "$2"; IMAGES="$2"; shift;;
    -q|--quality)	checkarg "quality" "$2"; QUALITY="$2"; shift;;
    -r|--resize)	checkarg "resize" "$2"; RESIZE=true; MAX="$2"; shift;;
    -w|--width)		checkarg "width" "$2"; WIDTH=true; MAX="$2"; shift;;
    -v|--height)	checkarg "vertical" "$2"; HEIGHT=true; MAX="$2"; shift;;
    -u|--unsharp)       UNSHARP="-unsharp 1.5x1+0.7+0.02" ;;
    -d|--day)		DAY=true ;;
    -j|--jpeg)		JPEG=true ;;
    -x|--png)		PNG=true ;;
    -h|--help)		HELP=true ;;
    *|-*|--*) showhelp; exit 1;;
  esac
  shift
done

if [ ${HELP} ]; then showhelp; exit 1; fi

# Apply default quality
[ ! -n "$QUALITY" ] && QUALITY=75

# Path should exist
[ ! -n "$IMAGES" ] && echo "Set a images path is mandatory. Exiting..." && exit 1

# Only one resize method is allowed, cannot resize with multiple conditions
[ $RESIZE ] && [ $WIDTH ] && echo "Cannot resize with multiple conditions, select only one, largest, width or height..." && exit 1
[ $RESIZE ] && [ $HEIGHT ] && echo "Cannot resize with multiple conditions, select only one, largest, width or height..." && exit 1
[ $WIDTH ] && [ $HEIGHT ] && echo "Cannot resize with multiple conditions, select only one, largest, width or height..." && exit 1

# Set minimum percentage of optimization to continue with file (percert)
MINOPT=5

# Check binaries
for binary in jpegoptim optipng identify mogrify convert
do
        if [ $(which ${binary} 2> /dev/null | wc -l) -eq 0 ]
        then
                echo "Please install following packages: jpegoptim, optipng, imagemagick"
                echo "(apt -y install jpegoptim optipng imagemagick)"
                exit 2;
        fi
done

# -----------------------------------------------------------------------------------------------------------------------------------
# PROCESSING

# Define the files to search for
[ $DAY ] && dayopts='-mtime -1 -daystart'
# Define format if applied
REGEX="\(png\|jpg\|jpeg\)"
[ $JPEG ] && REGEX="\(jpg\|jpeg\)"
[ $PNG ] && REGEX="png"

echo "====================================================================================================================="
echo "OPTIMIZING PATH: $IMAGES"
echo "OBJETIVE: $(if [ $DAY ]; then echo "Today "; else echo "All "; fi)$(if [ $PNG ]; then echo "PNG"; elif [ $JPEG ]; then echo "JPEG"; else echo "JPEG/PNG"; fi) files"
echo "QUALITY: ${QUALITY}% (stripping Comments|Exif|IPTC|ICC|XMP markers from files)"
if [ $RESIZE ] || [ $WIDTH ] || [ $HEIGHT ]; then echo "RESIZE: maximum $([ $RESIZE ] && echo "side")$([ $WIDTH ] && echo "width")$([ $HEIGHT ] && echo "height") size: ${MAX}px $([[ ! -z $UNSHARP ]] && echo " | Sharpness filter applied over shrinked images ($UNSHARP)")"; fi
echo "====================================================================================================================="

sleep 7

NUMFILES=$(eval "find $IMAGES -type f -iregex '.*\.${REGEX}' $dayopts" | sort | wc -l)
COUNTER=0

while IFS= read -r image
do
	echo ""
	echo "--"

	let "COUNTER=COUNTER+1"
	echo "Processing $COUNTER of $NUMFILES"

	echo ""
	echo "File: $image"

	# If image contains errors or cannot be decoded, just skip
	if ! identify "$image" > /dev/null 2>&1; then
		echo "$image -> is broken and cannot be decoded. Skipping."
		continue
	fi

	TYPE="$(file --mime-type -b "$image" | awk -F"/" '{print $2}')"
	filename=$(basename -- "$image") && EXTENSION="$(echo ${filename##*.} | tr '[:upper:]' '[:lower:]')"

	# --------------------------------------------------------------------------------------------------------------------------
	# APPLY RESIZE?

	# Check dimensions once
	IMGWIDTH=$(identify -format "%w" "$image")
	IMGHEIGHT=$(identify -format "%h" "$image")

	# Apply if resizing for largest dimension
	if [ $RESIZE ]
	then
		if [ $IMGWIDTH -gt $MAX ] || [ $IMGHEIGHT -gt $MAX ]
		then
			echo "Applying largest dimesion resize to $image (current: ${IMGWIDTH}x${IMGHEIGHT}px) (maximum width or height: ${MAX} pixels)"
			rsync -aE --quiet "$image" "${image}.old"
			nice -n 19 ionice -c idle convert "$image" -resize "${MAX}x${MAX}>" ${UNSHARP} "$image"
			touch -r "${image}.old" "$image"
	                rm -f "${image}.old"
		fi
	fi

        if [ $WIDTH ]
        then
                if [ $IMGWIDTH -gt $MAX ]
                then
                        echo "Applying Width resize to $image (current: ${IMGWIDTH}x${IMGHEIGHT}px) (maximum width: ${MAX} pixels)"
                        rsync -aE --quiet "$image" "${image}.old"
                        nice -n 19 ionice -c idle convert "$image" -resize "${MAX}" ${UNSHARP} "$image"
                        touch -r "${image}.old" "$image"
                        rm -f "${image}.old"
                fi
        fi

        if [ $HEIGHT ]
        then
                if [ $IMGHEIGHT -gt $MAX ]
                then
                        echo "Applying Height resize to $image (current: ${IMGWIDTH}x${IMGHEIGHT}px) (maximum height: ${MAX} pixels)"
                        rsync -aE --quiet "$image" "${image}.old"
                        nice -n 19 ionice -c idle convert "$image" -resize "x${MAX}" ${UNSHARP} "$image"
                        touch -r "${image}.old" "$image"
                        rm -f "${image}.old"
                fi
        fi




        # --------------------------------------------------------------------------------------------------------------------------
        # JPEG?

	if [ "$TYPE" == "jpeg" ]
	then
		nice -n 19 ionice -c idle jpegoptim -p -P -T$MINOPT -m$QUALITY --strip-all "$image"
	fi

        # --------------------------------------------------------------------------------------------------------------------------
        # PNG WITH JPEG EXTENSION?

	if [ "$TYPE" == "png" ]
	then
		if [ "$EXTENSION" == "png" ]
		then
			nice -n 19 ionice -c idle optipng -preserve -o2 -strip all "$image"
		else
			echo "Performing a conversion from png to jpg on $image"
			USER="$(stat -c "%U" "$image")"
			GROUP="$(stat -c "%G" "$image")"
			rsync -aE --quiet "$image" "${image}.old"
			mogrify -format jpg -colorspace rgb "$image"
			nice -n 19 ionice -c idle jpegoptim -p -P -T$MINOPT -m$QUALITY --strip-all "$image"
			chown $USER:$GROUP "$image"
			touch -r "${image}.old" "$image"
			rm -f "${image}.old"
		fi
	fi

done < <(eval "find $IMAGES -type f -iregex '.*\.${REGEX}' $dayopts" | sort)

echo "====================================================================================================================="
