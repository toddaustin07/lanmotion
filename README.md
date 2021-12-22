# SmartThings Edge Driver for LAN-based motion devices

## Description
This is a Samsung SmartThings Edge driver that provides the ability to create generic motion sensor devices for LAN-based devices and applications.  The driver requires the **forwarding bridge server** (https://github.com/toddaustin07/edgebridge) to act as an intermediary between the hub-based Edge driver and the LAN device/application.  This allows these LAN-based devices and applications to send extemparaneous HTTP requests to the driver without requiring more sophsiticated peer-to-peer connection code on both sides.  Devices & applications that allow for a simple HTTP request URL to be configured and sent upon an event trigger can thus be integrated simply with SmartThings.

### Features
- Each SmartThings device includes both a motion sensor and a tamper alert capability.
- Any number of devices can be created
- SmartThings Automation routines and Rules can be created to use the motion and tamper states as IF conditions

## Use Cases
### Shelly Motion Sensor
Shelly makes an excellent wifi motion sensor.  It has exceptional battery life and works well in environments with less-than-ideal wifi signal.  But unfortunately its integration with SmartThings is lacking.

There is currently no official local integration of Shelly's wifi Motion Sensors with SmartThings. There are cloud integrations available for other Shelly devices, but as of this writing there are none that support their motion sensor product.  However, these devices can be configured to send an HTTP message to a given IP/Port whenever motion or tampering is detected.  With this driver and the forwarding bridge server, this Shelly device can be configured to send these messages to the bridge server, which will then forward them to the Edge driver - all without any custom communications code needed.

#### Shelly Motion Sensor Configuration
The physical motion sensor device must be configured to send an HTTP message whenever it senses motion or tampering.  Follow these steps:
- Configure your router to give the device a static IP address
- Use a browser to access the Shelly Motion Sensor configuration page by typing the device's IP address into the web site address bar and pressing enter.  Note that it may take several seconds for the page to respond as the device needs to wake up; your browser may time-out initially, but eventually should display the config page
- Click on the **Actions** button
- Expand the **Motion Detected** section, click the **Enabled** checkbox, and enter the forwarding bridge server IP:port address plus endpoint string; for example:
```
http://192.168.1.140:8088/<name>/motion/active
```
Where *name* is a short name (no spaces; no special characters) for the device. This same name will also be configured in the corresponding Edge device settings later on.

Where */motion/active* must be included exactly as shown.

- Optionally do the same for the Tamper Detected section.
```
http://192.168.1.140:8088/<name>/tamper/detected
```
Where */tamper/detected* must be included exactly as shown.
- If you want to also send HTTP messages when motion or tamper ends, then you would use:
```
http://192.168.1.140:8088/<name>/motion/inactive
http://192.168.1.140:8088/<name>/tamper/clear
```
Where the endpoints following the name must be included exactly as shown.

- Click the **Save** button
- Don't forget to close the web browser page when done, or your device battery could get drained down

### Blue Iris camera
The Blue Iris server allows for configuring actions for a camera whenever it detects motion.  These actions can include a web request.  Today, this is typically directed at a cloud-based SmartApp for SmartThings integration.  But with this solution, the web requests can be directed to the bridge server and forwarded to an Edge driver for 100% local execution.  The forwarding bridge server can be run on the same machine as the Blue Iris server.

#### Blue Iris Configuration

- Go into the triggers and actions configuration, create a new action, and select **Web request or MQTT** from the action set list
- Select 'http://' from the drop-down list in front of the address box
- In the address box, enter the forwarding bridge server IP:port address plus endpoint string; for example:
```
192.168.1.140:8088/<name>/motion/active
```
Where *name* is a short name (no spaces; no special characters) for the device. This same name will also be configured in the corresponding Edge device settings later on.

Where */motion/active* must be included exactly as shown.
  
If you are configuring a separate action for when motion stops, you'd use the following in the address box:
```
192.168.1.140:8088/<name>/motion/inactive
```
Where */motion/inactive* must be included exactly as shown.

- Select OK to save

## Driver Installation and Configuration
The Edge Driver is installed like any other through a shared channel invitation (https://api.smartthings.com/invitation-web/accept?id=cc2197b9-2dce-4d88-b6a1-2d198a0dfdef).
Enroll your hub with the channel and select the **LAN Motion Device Driver** to install.  It could take up to 12 hours for the driver to be installed on your hub.

Once the driver is available on the hub, the mobile app is used to perform an Add device / Scan nearby, and a new device called **LAN Motion Device** is created and will be found in the 'No room assigned' room.  Additional devices can be created using the *Create new device* button on the device details screen.

Before the SmartThings device can be operational, the forwarding bridge server must be running on a computer on the same LAN as the SmartThings hub.  See the readme file for more information (https://github.com/toddaustin07/edgebridge/blob/main/README.md)

If the bridge server is running, the new SmartThings LAN Motion Device can be configured by going to the device details screen and tapping the 3 vertical dots in the upper right corner and then selecting Settings.  There are five options that will be displayed:
* Auto-revert - this option allows you to control the behavior of the SmartThings device when it receives an active motion or tamper detected message from the physical device via the bridge server.  Set to 'Auto-revert' to automatically revert back to motion inactive/tamper clear, or to 'No auto-revert' (leave in active/detected state)
* Auto-revert delay - If the Auto-revert behavior was selected above, then this is the number of seconds you can configure before reverting back to inactive/clear.
* LAN Device Name - short name (no spaces/no special characters) of your device; must match what was configured in the HTTP endpoint string on the device
* LAN Device Address - this is the IP address of the physical device or application; this should be a **static IP address**
* Bridge Address - this is the IP and port number address of the forwarding bridge server; this should be a static IP address.  The server port number can be configured by the user (see above), but **defaults to 8088**.

Once the Bridge address is configured, the driver will attempt to connect.  Messages should be visible on the server message console.

