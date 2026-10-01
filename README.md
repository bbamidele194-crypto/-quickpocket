
# QuickPocket Wallet - Complete Build Ready

Registration asks: Name, Number, NIN (11 digits) - No BVN

Business Account: Moniepoint MFB 8145726390 QUICKPOCKET WALLET (No personal name)

Features:
- Login Password
- Transaction PIN 4 digits
- Fingerprint / Face ID
- NIN Only Verification
- Customer Care

## Build on Codemagic

1. Create Firebase project at console.firebase.google.com
2. Add Android app with package com.quickpocket.wallet
3. Download google-services.json
4. Upload this entire project to GitHub
5. Place google-services.json in android/app/google-services.json on GitHub
6. Connect GitHub repo to codemagic.io
7. Build -> APK will be generated

If no google-services.json, app will still build but Firebase won't work. Use placeholder to test build.
