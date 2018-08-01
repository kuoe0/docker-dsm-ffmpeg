.SUFFIXES:

.PHONY: image
image:
	docker build -t kuoe0/dsm-ffmpeg-qsv .
