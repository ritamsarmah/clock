.PHONY: all debug run compile clean deploy

OUT := build
REMOTE := pi@clock:/home/pi

TARGET ?= time

all: debug

debug:
	mkdir -p $(OUT)
	odin build $(TARGET) -debug -o:none -out:$(OUT)/$(TARGET)

run: debug
	./build/$(TARGET)

# Compile only producing object files to link on Raspberry Pi
compile: clean
	mkdir -p $(OUT)
	odin build $(TARGET)  -target=linux_arm64 -build-mode=object -out:$(OUT)

clean:
	rm -rf $(OUT)

deploy: compile
	rsync -avz --delete $(OUT)/ $(REMOTE)/$(OUT)/
	rsync -avz build.sh $(REMOTE)
	ssh pi@clock "./build.sh $(TARGET)"
