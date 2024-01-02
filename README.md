# Kasm-Discord-Screenshare

Screenshare your [n.eko](https://github.com/m1k1o/neko), [MovieNight](https://github.com/zorchenhimer/MovieNight/tree/master), [Owncast](https://github.com/owncast/owncast), [Restreamer](https://github.com/datarhei/restreamer), **WebBrowser**, **rtmp**, or **WebRTC** streams directly to Discord without needing to use the same PC and tie up resources!

Utilizes [Discord Screen Audio](https://github.com/maltejur/discord-screenaudio.git) by [maltejur](https://github.com/maltejur/)

---

### Demo

**Working Demo**
- ![](https://github.com/f00d4tehg0dz/kasm-discord-screenshare/blob/main/screenshots/demo.gif)

**Instructions**
- ![](https://github.com/f00d4tehg0dz/kasm-discord-screenshare/blob/main/screenshots/instructions.gif)

---

### Prerequisites

Before you begin setting up the Kasm Workspace with our Docker image, ensure that you meet the following prerequisites:

1. **Docker**: You should have Docker installed on your system. If you haven't installed Docker yet, you can find the installation instructions on the [Official Docker Website](https://docs.docker.com/get-docker/).

2. **Basic Knowledge of Docker**: Familiarity with Docker commands and concepts is recommended to effectively use and troubleshoot the setup.

3. **Kasm Workspaces**: This setup is specifically designed for Kasm Workspaces. Ensure you have access to a Kasm Workspace environment or know how to set one up. For more information, visit the [Kasm Workspaces Official Documentation](https://www.kasmweb.com/docs/latest/).

4. **System Requirements**: Ensure your system meets the following requirements:
   - Minimum 4 CPU cores
   - At least 4096 MB of RAM
   - Sufficient disk space for persistent profile storage and Docker image

5. **Internet Connection**: A stable internet connection is necessary for downloading the Docker image and for seamless streaming performance.

6. **Discord Account**: While not a technical prerequisite, having a Discord account to test and use the screenshare functionality is essential.

---

### Installation Guide

Follow these steps to install and set up the Kasm Workspace with our Docker image for Discord screensharing:

1. **Pulling the Docker Image**:
   Start by pulling the latest version of our Docker image from the Docker Hub. Open your terminal and run the following command:
   ```bash
   docker pull f00d4tehg0dz/kasm-discord-screenshare:latest
   ```

2. **Setting Up Kasm Workspace**:
   Once the Docker image is pulled, set up your Kasm Workspace. If you haven't set up Kasm Workspaces before, refer to the [Kasm Workspaces Documentation](https://www.kasmweb.com/docs/latest/) for guidance.

3. **Configuring the Workspace**:
   Configure your Kasm Workspace with the required specifications. This includes setting the number of cores to `4`, memory to `4096 MB`, and specifying the Persistent Profile Path.

4. **Building the Docker Image (Optional)**:
   If you wish to build the Docker image locally, use the following command:
   ```bash
   sudo docker build -t jammy-discord-screenshare:sudo -f Dockerfile .
   ```

5. **Running the Docker Container**:
   To run the Docker container with the necessary configurations, use the command:
   ```bash
   sudo docker run --rm -it --shm-size=512m -p 6901:6901 -e VNC_PW=password jammy-discord-screenshare:sudo
   ```

6. **Verifying the Setup**:
   After running the Docker container, verify that the Kasm Workspace is set up correctly and that the Discord screenshare functionality is operational.

### Configuration Details

Understanding the configuration settings is crucial for optimizing the Docker image for your specific needs. Here's a breakdown of the key configuration elements:

- **Docker Image**:
  `f00d4tehg0dz/kasm-discord-screenshare:latest` is the Docker image used for the setup. It's optimized for screensharing on Discord via Kasm Workspaces.

- **Cores and Memory**:
  The setup requires 4 CPU cores and 4096 MB of memory to ensure smooth performance during screensharing.

- **Persistent Profile Path**:
  The path `/kasm_profiles/kasm_discord_screenshare/{username}/` is used for storing user profiles persistently. Replace `{username}` with your actual username.

- **Docker Run Config Override**:
  The JSON configuration provided in the README is for overriding the default Docker run configuration. It includes settings like `hostname` and `environment` variables. The environment variable `NVIDIA_DRIVER_CAPABILITIES` set to `all` is essential for leveraging NVIDIA hardware acceleration.

```bash
{
  "hostname": "kasm",
  "environment": {
    "NVIDIA_DRIVER_CAPABILITIES": "all"
  }
}
```

- **Volume Mappings**:
  The optional JSON configuration for volume mappings is provided to facilitate data sharing between the Docker container and the host. This includes settings like the path, binding mode, user ID (uid), and group ID (gid).

```bash
{
  "/kasm_data": {
    "bind": "/share",
    "mode": "rw",
    "uid": 1000,
    "gid": 1000,
    "required": true,
    "skip_check": false
  }
}
```

- **Running Mozilla Firefox in No-Sandbox Mode (Optional)**:
  If you prefer using Mozilla Firefox over Google Chrome, you can compile and run it in no-sandbox mode using the `--no-sandbox` flag. This requires editing the Dockerfile to replace Google Chrome with Mozilla Firefox `.deb`.
---

## FAQ

#### Can I screenshare and broadcast on a Discord server stage?

Yes you can! The screenshare button directly under the Discord Broadcast-Stage does not activate properly. Use the screenshare button in the left sidebar. 

#### Do I need a Discord account dedicated for this?

Preferably

#### Do I have to use Google Chrome?

No, you can compile and run Mozilla Firefox in no-sandbox mode.

```bash
--no-sandbox
```

Edit the **Dockerfile** and replace Google Chrome with Mozilla Firefox `.deb`

## Feedback

If you have any feedback, please open an issue! Thank you


## Acknowledgements

 - [Discord Screenaudio](https://github.com/maltejur/discord-screenaudio.git)
 - [Virtmic](https://github.com/edisionnano/Screenshare-with-audio-on-Discord-with-Linux/blob/main/virtmic?raw=true)
 - [Pipewire](https://gitlab.freedesktop.org/pipewire/pipewire/-/archive)
 - [Kasm Ubuntu Jammy Desktop](https://github.com/kasmtech/workspaces-images/blob/develop/dockerfile-kasm-ubuntu-jammy-desktop)
