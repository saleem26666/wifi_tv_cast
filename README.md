# TV WiFi Cast

Show your **full laptop desktop** on an Android phone / TV over WiFi.

## Recommended (full screen, no Chrome picker)

1. Install the APK on the phone → **Start receiver**
2. On the laptop open `laptop_sender\Start_Full_Screen_Cast.bat`
3. Enter the phone IP shown in the app
4. Entire desktop appears on the phone

Needs Python 3 with: `pip install mss pillow websocket-client`

## Optional (Chrome)

Open `https://IP:8443` → Advanced → Proceed → Share screen → **Entire screen**.  
Chrome always shows a picker; that is a browser security rule.
