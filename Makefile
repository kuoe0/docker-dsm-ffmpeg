.SUFFIXES:

.PHONY: image
image:
	docker build -t kuoe0/ffmpeg-vaapi .
