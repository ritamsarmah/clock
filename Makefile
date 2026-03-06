.PHONY: all debug-app run-app compile-app deploy-app run-server deploy-server clean

OUT := build
PROJECT := clock
HOST := pi@clock
REMOTE := $(HOST):/home/pi
APP ?= time

all: debug-app

debug-app:
	mkdir -p $(OUT)
	odin build apps/$(APP) -debug -o:none -out:$(OUT)/$(APP)

run-app: debug-app
	./build/$(APP)

# Compile only produces object files to link on Raspberry Pi
compile-app: clean
	mkdir -p $(OUT)
	odin build apps/$(APP) -target=linux_arm64 -build-mode=object -out:$(OUT)

deploy-app: compile-app
	rsync -avz --delete $(OUT)/ $(REMOTE)/$(OUT)/
	rsync -avz apps/build.sh $(REMOTE)
	ssh pi@clock "mkdir -p apps/ && ./build.sh $(APP) && mv $(APP) apps/"

run-server:
	APP_DIRECTORY=./build/ HOST=127.0.0.1 PORT=7143 go run server/main.go

# NOTE: Will need to enable service first by linking to /etc/systemd/system and running `sudo systemctl enable clock.service`
deploy-server:
	mkdir -p $(OUT)
	GOOS=linux GOARCH=arm GOARM=7 go build -o $(OUT)/$(PROJECT) server/main.go
	@echo "Deploying server to $(HOST)..."
	ssh $(HOST) "sudo systemctl stop $(PROJECT)"
	rsync -avz build/$(PROJECT) $(REMOTE)
	rsync -avz server/$(PROJECT).service $(REMOTE)
	ssh $(HOST) "sudo systemctl daemon-reload && sudo systemctl start $(PROJECT)"
	@echo "Deployment complete."

clean:
	rm -rf $(OUT)
