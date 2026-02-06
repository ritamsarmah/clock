## Introduction

This is a collection of various programs to run on a custom built digital "clock".

## Installation

These are instructions to compile locally before deploying to a Raspberry Pi to link and enable.

1. Compile program locally for Raspberry Pi

```sh
make compile
```

2. Copy necessary files to the Raspberry Pi

```sh
scp -r build/ pi@viz:/home/pi/
scp build.sh pi@viz:/home/pi/
scp viz.service pi@viz:/home/pi/
```

3. SSH into the Raspberry Pi to run the following configuration (once)

```sh
# Install dependencies
sudo apt install libsdl3-dev

# (Optional) Enable service to run on startup if desired
sudo ln -s /home/pi/viz.service /etc/systemd/system/viz.service
sudo systemctl enable viz.service
```

4. Build and restart the device.

```sh
./build.sh
sudo reboot
```

After making changes to the original source code, compile and copy over the `build/` again and run `build.sh` on the Raspberry Pi.
