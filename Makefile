.SUFFIXES:

.PHONY: image
image:
	docker build --build-arg MAKE_JOBS=$(shell nproc) -t kuoe0/dsm-ffmpeg-vaapi .
