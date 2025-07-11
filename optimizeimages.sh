#!/bin/bash

# VERSION 2. TODA LA PROGRAMACION ESTÁ REALIZADA POR GINO
# -----------------------------------------------------------------------------------------------------------------------------------
# VARIABLES

function showhelp {
        echo "
How to use it:
  $0 -p|--path <path> -q|--quality <quality> -r|--resize <pixels> [-d|--day] [-c|--convert] [-h|--help]

Select any of these options:
  -p, --path		Mandatory, select path where images are
  -q, --quality		Select final quality (default: 75%)
  -r, --resize		Select maximum size in pixels for the largest side, keeping aspect ratio
  -w, --width		Select maximum width in pixels for the images, keeping aspect ratio
  -v, --height		Select maximum height in pixels for the images, keeping aspect ratio
  -u, --unsharp		Unsharp resized/shrinked images by using: -unsharp 1.5x1+0.7+0.02
  -d, --day		Just to process ONLY the last 24 hours images
  -j, --jpeg            Process ONLY jpegs
  -x, --png             Process ONLY pngs
  -c, --convert         Convert pngs to jpegs keeping filename
  -l, --jpegli          Convert to jpeg using jpegli instead of jpegoptim
  -b, --xyb             Convert to jpg using jpegli with XYB color profile (best result, break compatibility with old Safaris previous to v17)
  -h, --help		Some help here!

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
        if [ "$1" == "images" ]; then
                matches=false
                while read somedir; do
                        if [ -d "$somedir" ]; then
                                matches=true
                                break
                        fi
                done < <(find $2 -type d 2>/dev/null)
                if ! ${matches}; then
                        echo "No directory found for entered Path. Exiting..."
                        echo ""
                        exit 1
                fi
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
    -c|--convert)	CONVERT=true ;;
    -l|--cjpegli)	CJPEGLI=true ;;
    -b|--xyb)		CJPEGLI=true; XYB=true ;;
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

if [ ! -e /usr/local/bin/cjpegli ] && [ "$CJPEGLI" == "true" ]
then
	apt install -y build-essential cmake git nasm pkg-config libpng-dev libturbojpeg-dev icc-profiles libjpeg-progs clang libstdc++-11-dev libstdc++-10-dev libstdc++-12-dev
	mkdir -p /root/soft && cd /root/soft
	git clone https://github.com/libjxl/libjxl.git --recursive --shallow-submodules
	cd libjxl && mkdir build && cd build
	export CC=clang CXX=clang++
	cmake -DCMAKE_BUILD_TYPE=Release -DJPEGXL_ENABLE_JPEGLI=ON -DJPEGXL_ENABLE_TOOLS=ON -DBUILD_TESTING=OFF ..
        cmake --build . -- -j$(nproc)
	#make -j$(nproc)
	checkinstall -y --pkgname="libjxl-tools" --pkgversion="$(date +%Y%m%d)-git" --pkgrelease="1" --pkgarch="$(dpkg --print-architecture)" --maintainer="Gino <gino@gino.es>" \
                     --pkggroup="graphics" --requires="libc6,libstdc++6,libpng16-16" --nodoc make install
	rsync -avE /root/soft/libjxl/build/libjxl-tools_*-git-1_amd64.deb /root/soft/
	ldconfig
fi


# -----------------------------------------------------------------------------------------------------------------------------------
# Functions

function compress_jpeg() {
	local image="$1"
	local PERMS
	local OWNER
	local GROUP
	local cjpegli_status
	local temp_output_file
	local reduction_percentage
	local gained_bytes
	local keep_file

	if [ "$CJPEGLI" == "true" ]; then
	        temp_output_file=$(mktemp "/tmp/cjpegli_temp_XXXXXX.jpg")

	        trap 'echo "Limpiando archivos temporales..."; rm -f "$temp_output_file"' EXIT ERR INT TERM

	        PERMS=$(stat -c '%a' "$image")
	        OWNER=$(stat -c '%u' "$image")
	        GROUP=$(stat -c '%g' "$image")

		if [ "$XYB" == "true" ]; then
	        	cjpegli "$image" "$temp_output_file" -q $QUALITY --xyb --chroma_subsampling=444 > /dev/null 2>&1
			cjpegli_status=$?
		else
                        cjpegli "$image" "$temp_output_file" -q $QUALITY --chroma_subsampling=444 > /dev/null 2>&1
                        cjpegli_status=$?
		fi

		if [ $cjpegli_status -ne 0 ]; then
			echo "Error: cjpegli falló para '$input_file' (código de salida: $cjpegli_status)."
			return 1
		fi

		if [ ! -f "$temp_output_file" ]; then
			echo "Error: cjpegli no generó el archivo de salida temporal '$temp_output_file'."
			return 1
		fi

		#exiftool -all= -tagsFromFile @ -icc_profile -overwrite_original "$$temp_output_file"

		initial_size=$(stat -c %s "$image")
		if [ "$initial_size" -eq 0 ]; then
			echo "Error: el tamaño inicial es cero, no se puede calcular el porcentaje."
			return 1
		fi
		final_size=$(stat -c %s "$temp_output_file")
		if [ $? -ne 0 ]; then
			echo "Error al obtener el tamaño final del archivo temporal '$temp_output_file'."
			return 1
		fi

		gained_bytes=$((initial_size - final_size))

		reduction_percentage=$(echo "scale=2; ($gained_bytes * 100) / $initial_size" | bc 2>/dev/null)

		echo "Tamaño inicial -> final: $initial_size -> $final_size bytes"
		printf "Porcentaje de reducción: %.2f%%\n" "$reduction_percentage"

		keep_file=$(echo "$reduction_percentage >= $MINOPT" | bc 2>/dev/null)

		if [ "$keep_file" = "1" ]
		then
			touch -r "$image" "$temp_output_file"
			mv "$temp_output_file" "$image"
			chown "$OWNER:$GROUP" "$image"
			chmod "$PERMS" "$image"
		else
			echo "Reduction threshold is lower than ${MINOPT}%. Keeping old file."
		fi

		rm -f "$temp_output_file"

		trap - EXIT ERR INT TERM

	else
	        nice -n 19 ionice -c idle jpegoptim -p -P -T"$MINOPT" -m"$QUALITY" --strip-all "$image"
	fi

	return 0
}


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
if [ $CONVERT ]; then echo "CONVERT: converting png files to jpg keeping filename (those without alpha channel only"; fi
echo "====================================================================================================================="

sleep 4

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
        # CONVERT PNG TO JPG KEEPING FILENAME?

        if [ $CONVERT ] && [ "$TYPE" == "png" ]
        then
		if [ $(identify -format "%A" "${image}" | grep -i True | wc -l) -gt 0 ]
		then
			echo "Cannot perform png2jpg conversion because png has alpha channel (transparencies)..."
		else
                        echo "Performing a conversion from png to jpg on: $image"
                        USER="$(stat -c "%U" "$image")"
                        GROUP="$(stat -c "%G" "$image")"
                        rsync -aE --quiet "$image" "${image}.old"
                        convert "$image" -colorspace rgb "$image.png2jpg.jpg"
			mv -f "$image.png2jpg.jpg" "$image"
                        chown $USER:$GROUP "$image"
                        touch -r "${image}.old" "$image"
                        rm -f "${image}.old"
			# Set type to continue processing
        		TYPE="jpeg"
		fi
        fi


	# --------------------------------------------------------------------------------------------------------------------------
	# APPLY RESIZE?

	# Apply if resizing for largest dimension
	if [ $RESIZE ]
	then
		IMGWIDTH=$(identify -format "%w" "$image")
		IMGHEIGHT=$(identify -format "%h" "$image")

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
                IMGWIDTH=$(identify -format "%w" "$image")
                IMGHEIGHT=$(identify -format "%h" "$image")

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
                IMGWIDTH=$(identify -format "%w" "$image")
                IMGHEIGHT=$(identify -format "%h" "$image")

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
		compress_jpeg "$image"
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
			compress_jpeg "$image"
			chown $USER:$GROUP "$image"
			touch -r "${image}.old" "$image"
			rm -f "${image}.old"
		fi
	fi

done < <(eval "find $IMAGES -type f -iregex '.*\.${REGEX}' $dayopts" | sort)

echo "====================================================================================================================="
