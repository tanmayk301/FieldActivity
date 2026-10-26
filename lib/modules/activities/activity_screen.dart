
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/local_db.dart';
import '../../services/location_service.dart';
import '../../services/photo_service.dart';
import '../../services/sync_service.dart';
import '../day_tracking/day_tracking_screen.dart';
import '../orders/orders_screen.dart';





class FieldActivityApp extends StatelessWidget {
  const FieldActivityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Field Activity',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B6E4F)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F8F7),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

final api = ApiService();

final localDb = LocalDb.instance;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();

  bool loading = false;

  Future<void> login() async {
    if (email.text.trim().isEmpty) return;

    setState(() => loading = true);

    try {
      final user = await api.login(email.text);

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('user_id', user.userId);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Image.asset('assets/field_force_connect_logo.png',
                        height: 150)),
                const SizedBox(height: 18),
                Text('Field Activity',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                    'Track distributor, retailer and farmer visits with GPS and activity history.'),
                const SizedBox(height: 32),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Company email'),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: loading ? null : login,
                    child: Text(loading ? 'Signing in…' : 'Continue'),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'V1 pilot authentication uses the active Users master. Google Workspace sign-in can be enabled before production rollout.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ActiveVisitData {
  final String userId;
  final String type;
  final String category;
  final String entityId;
  final String entityName;
  final String villageTown;
  final DateTime start;
  final double? startLat;
  final double? startLng;
  final String purpose;
  final String outcome;
  final String remarks;
  final List<String> photoPaths;

  const ActiveVisitData({
    required this.userId,
    required this.type,
    this.category = 'Field Visit',
    required this.entityId,
    required this.entityName,
    required this.villageTown,
    required this.start,
    this.startLat,
    this.startLng,
    this.purpose = '',
    this.outcome = '',
    this.remarks = '',
    this.photoPaths = const [],
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'type': type,
        'category': category,
        'entityId': entityId,
        'entityName': entityName,
        'villageTown': villageTown,
        'start': start.toIso8601String(),
        'startLat': startLat,
        'startLng': startLng,
        'purpose': purpose,
        'outcome': outcome,
        'remarks': remarks,
        'photoPaths': photoPaths,
      };

  factory ActiveVisitData.fromJson(Map<String, dynamic> j) => ActiveVisitData(
        userId: '${j['userId'] ?? ''}',
        type: '${j['type'] ?? ''}',
        category: '${j['category'] ?? 'Field Visit'}',
        entityId: '${j['entityId'] ?? ''}',
        entityName: '${j['entityName'] ?? ''}',
        villageTown: '${j['villageTown'] ?? ''}',
        start: DateTime.parse('${j['start']}'),
        startLat: (j['startLat'] as num?)?.toDouble(),
        startLng: (j['startLng'] as num?)?.toDouble(),
        purpose: '${j['purpose'] ?? ''}',
        outcome: '${j['outcome'] ?? ''}',
        remarks: '${j['remarks'] ?? ''}',
        photoPaths: (j['photoPaths'] as List? ?? []).map((e) => '$e').toList(),
      );
}

class ActiveVisitStore {
  static String _key(String userId) => 'active_visit_$userId';

  static Future<ActiveVisitData?> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null || raw.isEmpty) return null;
    try {
      return ActiveVisitData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await prefs.remove(_key(userId));
      return null;
    }
  }

  static Future<void> save(ActiveVisitData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(data.userId), jsonEncode(data.toJson()));
  }

  static Future<void> clear(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
  }
}

const _activityCategories = <(String, IconData)>[
  ('Product Demonstration', Icons.inventory_2_outlined),
  ('Farmer Meeting', Icons.groups_outlined),
  ('Field Day', Icons.event_available),
];

class HomeScreen extends StatefulWidget {
  final UserProfile user;
  const HomeScreen({super.key, required this.user});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int todayVisits = 0;
  int monthVisits = 0;
  int followUps = 0;
  bool syncing = false;
  ActiveVisitData? activeVisit;
  List<Map<String, dynamic>> recentActivities = [];

  Future<void> loadTodayVisits() async {
    final count = await localDb.todayVisitCount(widget.user.userId);
    final monthCount = await localDb.monthVisitCount(widget.user.userId);
    final active = await ActiveVisitStore.load(widget.user.userId);
    final recent = await localDb.recentActivities(widget.user.userId);
    if (mounted)
      setState(() {
        todayVisits = count;
        monthVisits = monthCount;
        activeVisit = active;
        recentActivities = recent;
      });
  }

  @override
  void initState() {
    super.initState();
    loadTodayVisits();
  }

  Future<void> sync() async {
    setState(() => syncing = true);
    final count = await SyncService(api, localDb).syncPending();
    if (mounted) {
      setState(() => syncing = false);
      await loadTodayVisits();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(count == 0
                ? 'Nothing to sync'
                : '$count activity records synced')),
      );
    }
  }

  Future<void> resumeActiveVisit() async {
    final active = await ActiveVisitStore.load(widget.user.userId);
    if (active == null) {
      await loadTodayVisits();
      return;
    }
    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => VisitScreen(
              user: widget.user,
              type: active.type,
              category: active.category,
              active: active)),
    );
    if (result == true) await loadTodayVisits();
  }

  void blockedActivity() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text(
              'Please complete the active visit before starting another activity.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Image.asset('assets/field_force_connect_logo.png',
              height: 34, width: 34),
          const SizedBox(width: 8),
          const Text('Field Activity'),
        ]),
        actions: [
          IconButton(
              tooltip: 'Sync',
              onPressed: syncing ? null : sync,
              icon: Icon(syncing ? Icons.sync : Icons.cloud_upload_outlined)),
          IconButton(
              tooltip: 'Profile',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => ProfileScreen(user: u))),
              icon: const Icon(Icons.person_outline)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadTodayVisits,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Good morning, ${u.name.split(' ').first}',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${u.territory} • ${u.district}',
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 20),
            if (activeVisit != null) ...[
              Card(
                color: const Color(0xFFE8F5E9),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.play_circle_fill,
                              color: Color(0xFF0B6E4F)),
                          const SizedBox(width: 8),
                          const Text('ACTIVE VISIT',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0B6E4F))),
                        ]),
                        const SizedBox(height: 10),
                        Text(activeVisit!.entityName,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('${activeVisit!.type} Visit'),
                        const SizedBox(height: 4),
                        Text(
                            'Started ${TimeOfDay.fromDateTime(activeVisit!.start).format(context)}',
                            style: const TextStyle(color: Colors.black54)),
                        const SizedBox(height: 10),
                        SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                                onPressed: resumeActiveVisit,
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Resume Visit'))),
                      ]),
                ),
              ),
              const SizedBox(height: 14),
            ],
            
            Row(children: [
              Expanded(
                  child: _stat(
                      'Today’s visits', '$todayVisits', Icons.event_note)),
              const SizedBox(width: 12),
              Expanded(
                  child: _stat('Visits this month', '$monthVisits',
                      Icons.calendar_month)),
            ]),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.speed),
                ),
                title: const Text(
                  'Start Day / End Day',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Record odometer reading and mandatory photo',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DayTrackingScreen(user: u),
                    ),
                  );
                },
              ),
            ),
            
Card(
  child: ListTile(
    leading: const CircleAvatar(
      child: Icon(Icons.shopping_cart_outlined),
    ),
    title: const Text(
      'Distributor Orders',
      style: TextStyle(fontWeight: FontWeight.w600),
    ),
    subtitle: const Text(
      'Create and track distributor orders',
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrdersScreen(user: u),
        ),
      );
    },
  ),
),

            const SizedBox(height: 22),
            const Text('Start activity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _entityVisitTile(
                'Distributor Visit', 'Distributor', Icons.store_mall_directory),
            _entityVisitTile('Retailer Visit', 'Retailer', Icons.storefront),
            _entityVisitTile('Farmer Visit', 'Farmer', Icons.agriculture),
            _fieldActivitiesTile(),
            const SizedBox(height: 22),
            const Text('Recent activity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (recentActivities.isEmpty)
              const Card(
                  child: ListTile(
                      leading: CircleAvatar(child: Icon(Icons.history)),
                      title: Text('No activity recorded yet'),
                      subtitle: Text('Completed visits will appear here.')))
            else
              for (final activity in recentActivities)
                _recentActivityTile(activity),
          ],
        ),
      ),
    );
  }

  Widget _stat(String title, String value, IconData icon) => Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(icon, color: const Color(0xFF0B6E4F)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
                Text(title, style: const TextStyle(color: Colors.black54))
              ])
            ])),
      );

  Widget _recentActivityTile(Map<String, dynamic> activity) {
    final type =
        '${activity['Activity_Type'] ?? activity['Activity_Category'] ?? 'Activity'}';
    final entityType = '${activity['Entity_Type'] ?? ''}';
    final entityId =
        '${activity['Entity_ID'] ?? activity['Farmer_Name'] ?? ''}';
    final date = '${activity['Activity_Date'] ?? ''}';
    final synced = activity['_synced'] == true;
    return Card(
        child: ListTile(
      leading: CircleAvatar(
          child: Icon(synced
              ? Icons.check_circle_outline
              : Icons.cloud_upload_outlined)),
      title: Text(type, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
          [entityType, entityId, date].where((v) => v.isNotEmpty).join(' • ')),
      trailing: Text(synced ? 'Synced' : 'Queued',
          style: TextStyle(
              color: synced ? const Color(0xFF0B6E4F) : Colors.orange.shade800,
              fontSize: 12)),
    ));
  }

  Widget _entityVisitTile(String title, String type, IconData icon) => Card(
        child: ListTile(
          enabled: activeVisit == null,
          leading: CircleAvatar(child: Icon(icon)),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(activeVisit == null
              ? 'Select from your $type master'
              : 'Complete active visit first'),
          trailing: const Icon(Icons.chevron_right),
          onTap: activeVisit != null
              ? blockedActivity
              : () async {
                  final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EntityListScreen(
                            user: widget.user,
                            type: type,
                            category: 'Field Visit'),
                      ));
                  if (result == true) await loadTodayVisits();
                },
        ),
      );

  Widget _fieldActivitiesTile() => Card(
        child: ListTile(
          enabled: activeVisit == null,
          leading: const CircleAvatar(child: Icon(Icons.event_note)),
          title: const Text('Field Activities',
              style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(activeVisit == null
              ? 'Demonstrations, trial plots, and meetings'
              : 'Complete active visit first'),
          trailing: const Icon(Icons.chevron_right),
          onTap: activeVisit != null
              ? blockedActivity
              : () async {
                  final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            FieldActivitiesScreen(user: widget.user),
                      ));
                  if (result == true) await loadTodayVisits();
                },
        ),
      );
}

class FieldActivitiesScreen extends StatelessWidget {
  final UserProfile user;
  const FieldActivitiesScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Field Activities')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Choose an activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          for (final item in _activityCategories)
            Card(
                child: ListTile(
              leading: CircleAvatar(child: Icon(item.$2)),
              title: Text(item.$1,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FieldActivityFormScreen(
                          user: user, category: item.$1),
                    ));
                if (result == true && context.mounted)
                  Navigator.pop(context, true);
              },
            )),
        ]),
      );
}

class FieldActivityFormScreen extends StatefulWidget {
  final UserProfile user;
  final String category;
  const FieldActivityFormScreen(
      {super.key, required this.user, required this.category});

  @override
  State<FieldActivityFormScreen> createState() =>
      _FieldActivityFormScreenState();
}

class _FieldActivityFormScreenState extends State<FieldActivityFormScreen> {
  final farmerName = TextEditingController();
  final farmerPhone = TextEditingController();
  final crop = TextEditingController();
  final variety = TextEditingController();
  final village = TextEditingController();
  final quantity = TextEditingController();
  final acreage = TextEditingController();
  final attendees = TextEditingController();
  final List<EntityRecord> distributors = [];
  final List<EntityRecord> retailers = [];
  final List<Map<String, dynamic>> productDemos = [];
  String? distributorId;
  String? retailerId;
  String? productDemoId;
  bool? largeTrialPlot;
  DateTime activityDate = DateTime.now();
  File? photo;
  bool loading = false;
  bool saving = false;
  String loadError = '';

  bool get isProductDemo => widget.category == 'Product Demonstration';
  bool get isFarmerMeeting => widget.category == 'Farmer Meeting';
  bool get isFieldDay => widget.category == 'Field Day';

  @override
  void initState() {
    super.initState();
    _loadChoices();
  }

  Future<void> _loadChoices() async {
    if (!isFarmerMeeting && !isFieldDay) return;
    setState(() {
      loading = true;
      loadError = '';
    });
    try {
      if (isFarmerMeeting) {
        final results = await Future.wait([
          api.getEntities('Distributor', widget.user),
          api.getEntities('Retailer', widget.user),
        ]);
        distributors.addAll(results[0]);
        retailers.addAll(results[1]);
      } else {
        final local = await localDb.activityPayloads(
            widget.user.userId, 'Product Demonstration');
        for (final item in local) {
          if ('${item['Activity_ID'] ?? ''}'.isNotEmpty) productDemos.add(item);
        }
        try {
          final remote = await api.getProductDemonstrations(widget.user.userId);
          for (final item in remote) {
            final id = '${item['Activity_ID'] ?? ''}';
            if (id.isNotEmpty &&
                !productDemos.any((x) => '${x['Activity_ID'] ?? ''}' == id))
              productDemos.add(item);
          }
        } catch (_) {
          if (productDemos.isEmpty) rethrow;
        }
      }
    } catch (e) {
      loadError = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: activityDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => activityDate = picked);
  }

  Future<void> _choosePhoto() async {
    final source = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
                child: Wrap(children: [
              ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Take Photo'),
                  onTap: () => Navigator.pop(ctx, 'camera')),
              ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from Gallery'),
                  onTap: () => Navigator.pop(ctx, 'gallery')),
            ])));
    if (source == null) return;
    final picked = source == 'camera'
        ? await PhotoService.takePhoto()
        : await PhotoService.pickFromGallery();
    if (picked != null && mounted) setState(() => photo = picked);
  }

  String _dateText(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _validate() {
    final missing = isProductDemo
        ? farmerName.text.trim().isEmpty ||
            farmerPhone.text.trim().isEmpty ||
            crop.text.trim().isEmpty ||
            variety.text.trim().isEmpty ||
            village.text.trim().isEmpty ||
            quantity.text.trim().isEmpty ||
            acreage.text.trim().isEmpty ||
            largeTrialPlot == null
        : isFarmerMeeting
            ? village.text.trim().isEmpty ||
                crop.text.trim().isEmpty ||
                distributorId == null ||
                retailerId == null ||
                attendees.text.trim().isEmpty
            : productDemoId == null || attendees.text.trim().isEmpty;
    final numericInvalid = isProductDemo
        ? double.tryParse(quantity.text.trim()) == null ||
            double.tryParse(acreage.text.trim()) == null
        : ((isFarmerMeeting || isFieldDay) &&
            (int.tryParse(attendees.text.trim()) == null ||
                (int.tryParse(attendees.text.trim()) ?? 0) < 1));
    if (missing || numericInvalid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Complete all required fields to save the activity.')));
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (saving || !_validate()) return;
    setState(() => saving = true);
    try {
      double? latitude, longitude;
      try {
        final position = await LocationService.current();
        latitude = position.latitude;
        longitude = position.longitude;
      } catch (_) {}
      final image = photo;
      final payload = <String, dynamic>{
        'Activity_ID': 'ACT-${DateTime.now().millisecondsSinceEpoch}',
        'User_ID': widget.user.userId,
        'Activity_Type': widget.category,
        'Activity_Category': widget.category,
        'Entity_Type': 'Field Activity',
        'Entity_ID': '',
        'Activity_Date': _dateText(activityDate),
        'Field_Day_Date': isFieldDay ? _dateText(activityDate) : '',
        'Created_DateTime': DateTime.now().toIso8601String(),
        'Latitude': latitude,
        'Longitude': longitude,
      };
      if (image != null) {
        payload.addAll({
          'Photo_Data_Base64': base64Encode(await image.readAsBytes()),
          'Photo_Mime_Type': image.path.toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg',
          'Photo_File_Name': image.uri.pathSegments.isEmpty
              ? 'field-activity.jpg'
              : image.uri.pathSegments.last,
        });
      }
      if (isProductDemo) {
        payload.addAll({
          'Farmer_Name': farmerName.text.trim(),
          'Farmer_Phone': farmerPhone.text.trim(),
          'Crop': crop.text.trim(),
          'Variety': variety.text.trim(),
          'Village': village.text.trim(),
          'Demo_Date': _dateText(activityDate),
          'Demo_Qty_KG': double.tryParse(quantity.text.trim()),
          'Demo_Acreage': double.tryParse(acreage.text.trim()),
          'Large_Trial_Plot': largeTrialPlot,
          'Farmers_Attended': '',
          'Product_Demo_ID': '',
          'Distributor_ID': '',
          'Distributor_Name': '',
          'Retailer_ID': '',
          'Retailer_Name': '',
        });
      } else if (isFarmerMeeting) {
        final distributor =
            distributors.firstWhere((e) => e.id == distributorId);
        final retailer = retailers.firstWhere((e) => e.id == retailerId);
        payload.addAll({
          'Farmer_Name': '',
          'Farmer_Phone': '',
          'Crop': crop.text.trim(),
          'Variety': '',
          'Village': village.text.trim(),
          'Demo_Date': '',
          'Demo_Qty_KG': '',
          'Demo_Acreage': '',
          'Large_Trial_Plot': '',
          'Farmers_Attended': int.tryParse(attendees.text.trim()),
          'Product_Demo_ID': '',
          'Distributor_ID': distributor.id,
          'Distributor_Name': distributor.name,
          'Retailer_ID': retailer.id,
          'Retailer_Name': retailer.name,
        });
      } else {
        final demo = productDemos
            .firstWhere((e) => '${e['Activity_ID'] ?? ''}' == productDemoId);
        payload.addAll({
          'Farmer_Name': '${demo['Farmer_Name'] ?? ''}',
          'Farmer_Phone': '${demo['Farmer_Phone'] ?? ''}',
          'Crop': '${demo['Crop'] ?? ''}',
          'Variety': '${demo['Variety'] ?? ''}',
          'Village': '${demo['Village'] ?? ''}',
          'Demo_Date': '',
          'Demo_Qty_KG': '',
          'Demo_Acreage': '',
          'Large_Trial_Plot': '',
          'Farmers_Attended': int.tryParse(attendees.text.trim()),
          'Product_Demo_ID': productDemoId,
          'Distributor_ID': '',
          'Distributor_Name': '',
          'Retailer_ID': '',
          'Retailer_Name': '',
        });
      }

      await localDb.queueActivity(payload);
      final synced = await SyncService(api, localDb).syncPending();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(synced > 0
              ? 'Activity saved and synced'
              : 'Activity saved and queued to sync')));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save activity: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _textField(TextEditingController controller, String label,
          {TextInputType? keyboardType}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(labelText: label)),
      );

  Widget _dateField() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
            onTap: _chooseDate,
            child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date'),
                child: Row(children: [
                  const Icon(Icons.calendar_month),
                  const SizedBox(width: 10),
                  Text(_dateText(activityDate))
                ]))),
      );

  Widget _photoField() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Card(
            child: ListTile(
          leading: photo == null
              ? const Icon(Icons.photo_camera_outlined)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(photo!,
                      width: 48, height: 48, fit: BoxFit.cover)),
          title: Text(
              photo == null ? 'Photograph (optional)' : 'Photograph added'),
          subtitle: const Text('You can add one now or save without it.'),
          trailing: IconButton(
              onPressed: _choosePhoto, icon: const Icon(Icons.add_a_photo)),
        )),
      );

  @override
  void dispose() {
    farmerName.dispose();
    farmerPhone.dispose();
    crop.dispose();
    variety.dispose();
    village.dispose();
    quantity.dispose();
    acreage.dispose();
    attendees.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.category)),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                if (loadError.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(loadError,
                          style: const TextStyle(color: Colors.red))),
                if (isProductDemo) ...[
                  _textField(farmerName, 'Farmer name *'),
                  _textField(farmerPhone, 'Farmer phone number *',
                      keyboardType: TextInputType.phone),
                  _textField(crop, 'Crop *'),
                  _textField(variety, 'Variety *'),
                  _textField(village, 'Village *'),
                  _dateField(),
                  _textField(quantity, 'Demo quantity (KG) *',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true)),
                  _textField(acreage, 'Demo acreage *',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true)),
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<bool>(
                          value: largeTrialPlot,
                          decoration: const InputDecoration(
                              labelText: 'Large trial plot? *'),
                          items: const [
                            DropdownMenuItem(value: true, child: Text('Yes')),
                            DropdownMenuItem(value: false, child: Text('No'))
                          ],
                          onChanged: (v) =>
                              setState(() => largeTrialPlot = v))),
                ] else if (isFarmerMeeting) ...[
                  _textField(village, 'Village *'),
                  _textField(crop, 'Crop *'),
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                          value: distributorId,
                          decoration: const InputDecoration(
                              labelText: 'Associated distributor *'),
                          items: distributors
                              .map((e) => DropdownMenuItem(
                                  value: e.id, child: Text(e.name)))
                              .toList(),
                          onChanged: (v) => setState(() => distributorId = v))),
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                          value: retailerId,
                          decoration: const InputDecoration(
                              labelText: 'Associated retailer *'),
                          items: retailers
                              .map((e) => DropdownMenuItem(
                                  value: e.id, child: Text(e.name)))
                              .toList(),
                          onChanged: (v) => setState(() => retailerId = v))),
                  _textField(attendees, 'No. of farmers attended *',
                      keyboardType: TextInputType.number),
                ] else ...[
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                          value: productDemoId,
                          decoration: const InputDecoration(
                              labelText: 'Product demonstration *'),
                          items: productDemos.map((e) {
                            final id = '${e['Activity_ID'] ?? ''}';
                            final label =
                                '${e['Farmer_Name'] ?? 'Farmer'} • ${e['Crop'] ?? 'Crop'} • ${e['Village'] ?? 'Village'}';
                            return DropdownMenuItem(
                                value: id,
                                child: Text(label,
                                    overflow: TextOverflow.ellipsis));
                          }).toList(),
                          onChanged: (v) => setState(() => productDemoId = v))),
                  if (!loading && productDemos.isEmpty)
                    const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                            'No Product Demonstration is available yet. Save a Product Demonstration first.')),
                  _dateField(),
                  _textField(attendees, 'No. of farmers attended *',
                      keyboardType: TextInputType.number),
                ],
                _photoField(),
                const SizedBox(height: 8),
                FilledButton.icon(
                    onPressed: saving || loading ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(saving ? 'Saving…' : 'Save activity')),
              ]),
      );
}

class ProfileScreen extends StatelessWidget {
  final UserProfile user;

  const ProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final rows = {
      'Name': user.name,
      'Employee Code': user.employeeCode,
      'Email': user.email,
      'Zone': user.zone,
      'Region': user.region,
      'Territory': user.territory,
      'State': user.state,
      'District': user.district,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: rows.entries
            .map((e) => Card(
                  child: ListTile(
                      title: Text(e.key,
                          style: const TextStyle(color: Colors.black54)),
                      subtitle: Text(e.value,
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                ))
            .toList(),
      ),
    );
  }
}

class EntityListScreen extends StatefulWidget {
  final UserProfile user;
  final String type;
  final String category;
  const EntityListScreen(
      {super.key,
      required this.user,
      required this.type,
      this.category = 'Field Visit'});
  @override
  State<EntityListScreen> createState() => _EntityListScreenState();
}

class _EntityListScreenState extends State<EntityListScreen> {
  final search = TextEditingController();
  List<EntityRecord> all = [];
  bool loading = true;
  String error = '';
  ActiveVisitData? activeVisit;
  bool get canAdd => widget.type == 'Retailer' || widget.type == 'Farmer';

  @override
  void initState() {
    super.initState();
    load();
    loadActive();
  }

  Future<void> loadActive() async {
    final a = await ActiveVisitStore.load(widget.user.userId);
    if (mounted) setState(() => activeVisit = a);
  }

  Future<void> load() async {
    try {
      final items = await api.getEntities(widget.type, widget.user);
      if (mounted)
        setState(() {
          all = items;
          loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          error = '$e';
          loading = false;
        });
    }
  }

  void blocked() => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text(
          'Please complete the active visit before starting another activity.')));

  Future<void> openEntity(EntityRecord e) async {
    if (activeVisit != null) {
      blocked();
      return;
    }
    final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => VisitScreen(
                user: widget.user,
                type: widget.type,
                category: widget.category,
                entity: e)));
    if (result == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final q = search.text.toLowerCase();
    final shown = all
        .where((e) =>
            e.name.toLowerCase().contains(q) || e.id.toLowerCase().contains(q))
        .toList();
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.category == 'Field Visit'
              ? '${widget.type} Visit'
              : widget.category)),
      floatingActionButton: canAdd
          ? FloatingActionButton.extended(
              onPressed: activeVisit != null
                  ? blocked
                  : () async {
                      final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => NewEntityScreen(
                                  user: widget.user,
                                  type: widget.type,
                                  category: widget.category)));
                      if (result == true && mounted)
                        Navigator.pop(context, true);
                    },
              icon: const Icon(Icons.add),
              label: Text('New ${widget.type}'),
            )
          : null,
      body: Column(children: [
        if (activeVisit != null)
          Card(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              color: const Color(0xFFFFF3E0),
              child: ListTile(
                  leading: const Icon(Icons.lock_clock),
                  title: const Text('Active visit in progress',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      '${activeVisit!.entityName} • ${activeVisit!.type} Visit'),
                  trailing: TextButton(
                      onPressed: () async {
                        final r = await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => VisitScreen(
                                    user: widget.user,
                                    type: activeVisit!.type,
                                    category: activeVisit!.category,
                                    active: activeVisit)));
                        if (r == true && mounted) Navigator.pop(context, true);
                      },
                      child: const Text('Resume')))),
        Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search by name or ID'))),
        if (error.isNotEmpty)
          Padding(padding: const EdgeInsets.all(16), child: Text(error)),
        Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (_, i) {
                      final e = shown[i];
                      return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 5),
                          child: ListTile(
                              title: Text(e.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: FutureBuilder<int>(
                                  future: localDb.entityMonthVisitCount(
                                      widget.user.userId, widget.type, e.id),
                                  builder: (_, snap) => Text(
                                      '${e.id} • Visits this month: ${snap.data ?? '…'}')),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => openEntity(e)));
                    })),
      ]),
    );
  }
}

class NewEntityScreen extends StatefulWidget {
  final UserProfile user;

  final String type;
  final String category;

  const NewEntityScreen(
      {super.key,
      required this.user,
      required this.type,
      this.category = 'Field Visit'});

  @override
  State<NewEntityScreen> createState() => _NewEntityScreenState();
}

class _NewEntityScreenState extends State<NewEntityScreen> {
  final name = TextEditingController();

  final mobile = TextEditingController();

  final village = TextEditingController();

  final address = TextEditingController();

  final contactPerson = TextEditingController();

  final crop = TextEditingController();

  final landAcreage = TextEditingController();

  final List<EntityRecord> distributors = [];

  final List<EntityRecord> retailers = [];

  String? distributorId;

  String? retailerId;

  bool saving = false;

  bool loadingLinks = false;

  bool get isFarmer => widget.type == 'Farmer';

  String _nameFor(List<EntityRecord> records, String? id) {
    for (final record in records) {
      if (record.id == id) return record.name;
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _loadLinkedMasters();
  }

  Future<void> _loadLinkedMasters() async {
    setState(() => loadingLinks = true);
    try {
      final values = await Future.wait([
        api.getEntities('Distributor', widget.user),
        if (isFarmer) api.getEntities('Retailer', widget.user),
      ]);
      distributors.addAll(values[0]);
      if (isFarmer && values.length > 1) retailers.addAll(values[1]);
    } catch (_) {
      // The entity can still be created while offline; linked master fields stay empty.
    } finally {
      if (mounted) setState(() => loadingLinks = false);
    }
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty) return;

    setState(() => saving = true);

    try {
      final pos = await LocationService.current();

      final item = await api.createEntity(
        type: widget.type,
        user: widget.user,
        fields: {
          'Name': name.text.trim(),
          'Mobile': mobile.text.trim(),
          'Village_Town': village.text.trim(),
          'Address': address.text.trim(),
          'Contact_Person': contactPerson.text.trim(),
          'Crop': crop.text.trim(),
          'Land_Acreage': landAcreage.text.trim(),
          'Distributor_ID': distributorId ?? '',
          'Distributor_Name': _nameFor(distributors, distributorId),
          'Retailer_ID': retailerId ?? '',
          'Retailer_Name': _nameFor(retailers, retailerId),
          'Latitude': pos.latitude,
          'Longitude': pos.longitude,
        },
      );

      if (!mounted) return;

      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => VisitScreen(
                  user: widget.user,
                  type: widget.type,
                  category: widget.category,
                  entity: item)));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('New ${widget.type}')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
                'This record will be assigned to your geography automatically.',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            TextField(
                controller: name,
                decoration:
                    InputDecoration(labelText: '${widget.type} name *')),
            const SizedBox(height: 12),
            TextField(
                controller: mobile,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobile number')),
            const SizedBox(height: 12),
            TextField(
                controller: contactPerson,
                decoration: const InputDecoration(labelText: 'Contact person')),
            const SizedBox(height: 12),
            TextField(
                controller: village,
                decoration: const InputDecoration(labelText: 'Village / Town')),
            const SizedBox(height: 12),
            TextField(
                controller: address,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Address')),
            const SizedBox(height: 12),
            if (loadingLinks)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator()))
            else
              DropdownButtonFormField<String>(
                value: distributorId,
                decoration:
                    const InputDecoration(labelText: 'Associated distributor'),
                items: distributors
                    .map((e) => DropdownMenuItem(
                        value: e.id, child: Text('${e.name} (${e.id})')))
                    .toList(),
                onChanged: (value) => setState(() => distributorId = value),
              ),
            if (isFarmer) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: retailerId,
                decoration:
                    const InputDecoration(labelText: 'Associated retailer'),
                items: retailers
                    .map((e) => DropdownMenuItem(
                        value: e.id, child: Text('${e.name} (${e.id})')))
                    .toList(),
                onChanged: (value) => setState(() => retailerId = value),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: crop,
                  decoration: const InputDecoration(labelText: 'Crop')),
              const SizedBox(height: 12),
              TextField(
                  controller: landAcreage,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Land acreage')),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: saving ? null : save,
              icon: const Icon(Icons.my_location),
              label: Text(saving ? 'Saving…' : 'Save & Start Visit'),
            ),
          ],
        ),
      );
}

class VisitScreen extends StatefulWidget {
  final UserProfile user;
  final String type;
  final String category;
  final EntityRecord? entity;
  final ActiveVisitData? active;

  const VisitScreen(
      {super.key,
      required this.user,
      required this.type,
      this.category = 'Field Visit',
      this.entity,
      this.active})
      : assert(entity != null || active != null);

  @override
  State<VisitScreen> createState() => _VisitScreenState();
}

class _VisitScreenState extends State<VisitScreen> {
  late DateTime start;
  double? startLat, startLng;
  bool visitStarted = false;
  final purpose = TextEditingController();
  final outcome = TextEditingController();
  final remarks = TextEditingController();
  final List<File> photos = [];
  bool finishing = false;
  bool leaving = false;

  String get entityId => widget.active?.entityId ?? widget.entity!.id;
  String get entityName => widget.active?.entityName ?? widget.entity!.name;
  String get villageTown =>
      widget.active?.villageTown ?? widget.entity!.villageTown;

  @override
  void initState() {
    super.initState();
    if (widget.active != null) {
      final a = widget.active!;
      start = a.start;
      startLat = a.startLat;
      startLng = a.startLng;
      purpose.text = a.purpose;
      outcome.text = a.outcome;
      remarks.text = a.remarks;
      photos.addAll(
          a.photoPaths.map((p) => File(p)).where((f) => f.existsSync()));
      visitStarted = true;
    }
  }

  Future<void> startVisit() async {
    final existing = await ActiveVisitStore.load(widget.user.userId);
    if (existing != null) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Another visit is already active.')));
      return;
    }
    start = DateTime.now();
    setState(() => visitStarted = true);
    await _captureStart();
    await _persistActive();
  }

  Future<void> _captureStart() async {
    try {
      final p = await LocationService.current();
      if (mounted)
        setState(() {
          startLat = p.latitude;
          startLng = p.longitude;
        });
      if (visitStarted) await _persistActive();
    } catch (_) {}
  }

  Future<void> _persistActive() async {
    if (!visitStarted) return;
    await ActiveVisitStore.save(ActiveVisitData(
      userId: widget.user.userId,
      type: widget.type,
      category: widget.category,
      entityId: entityId,
      entityName: entityName,
      villageTown: villageTown,
      start: start,
      startLat: startLat,
      startLng: startLng,
      purpose: purpose.text.trim(),
      outcome: outcome.text.trim(),
      remarks: remarks.text.trim(),
      photoPaths: photos.map((f) => f.path).toList(),
    ));
  }

  Future<void> _backFromVisit() async {
    if (!visitStarted || leaving) return;
    leaving = true;
    await _persistActive();
    if (mounted) Navigator.pop(context);
  }

  Future<void> addPhoto() async {
    if (photos.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 3 photographs per visit')));
      return;
    }
    final source = await showModalBottomSheet<String>(
        context: context,
        builder: (_) => SafeArea(
                child: Wrap(children: [
              ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Take Photo'),
                  onTap: () => Navigator.pop(context, 'camera')),
              ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from Gallery'),
                  onTap: () => Navigator.pop(context, 'gallery')),
            ])));
    File? file;
    if (source == 'camera') file = await PhotoService.takePhoto();
    if (source == 'gallery') file = await PhotoService.pickFromGallery();
    if (file != null && mounted) {
      setState(() => photos.add(file!));
      await _persistActive();
    }
  }

  Future<void> complete() async {
    if (!visitStarted) return;
    setState(() => finishing = true);
    try {
      final end = DateTime.now();
      double? endLat, endLng;
      try {
        final p = await LocationService.current();
        endLat = p.latitude;
        endLng = p.longitude;
      } catch (_) {}
      final activityId = 'ACT-${DateTime.now().millisecondsSinceEpoch}';
      final photoUploads = <Map<String, String>>[];
      for (var index = 0; index < photos.length; index++) {
        final file = photos[index];
        if (!await file.exists()) continue;
        photoUploads.add({
          'data': base64Encode(await file.readAsBytes()),
          'mimeType': 'image/jpeg',
          'fileName': '${activityId}_${index + 1}.jpg',
        });
      }
      final payload = {
        'Activity_ID': activityId,
        'User_ID': widget.user.userId,
        'Activity_Type': '${widget.type} Visit',
        'Activity_Category': widget.category,
        'Entity_Type': widget.type,
        'Entity_ID': entityId,
        'Activity_Date': start.toIso8601String().substring(0, 10),
        'Start_Time': start.toIso8601String(),
        'End_Time': end.toIso8601String(),
        'Duration_Min': end.difference(start).inMinutes,
        'Start_Latitude': startLat,
        'Start_Longitude': startLng,
        'End_Latitude': endLat,
        'End_Longitude': endLng,
        'Purpose': purpose.text.trim(),
        'Outcome': outcome.text.trim(),
        'Remarks': remarks.text.trim(),
        'Photo_Count': photos.length,
        'Photo_Data_Base64_List': photoUploads,
        'Created_DateTime': DateTime.now().toIso8601String(),
      };
      await localDb.queueActivity(payload);
      Map<String, dynamic>? serverResponse;
      Object? syncError;
      String? blockedActivity;
      bool offline = false;
      await SyncService(api, localDb).syncPending(
        targetActivityId: '${payload['Activity_ID']}',
        onTargetSynced: (response) => serverResponse = response,
        onTargetError: (error) => syncError = error,
        onSyncBlocked: (activityId, activityType, error) {
          blockedActivity =
              '${activityType.isEmpty ? 'Unknown activity' : activityType}'
              '${activityId.isEmpty ? '' : ' ($activityId)'}: $error';
        },
        onOffline: () => offline = true,
      );
      await ActiveVisitStore.clear(widget.user.userId);
      if (!mounted) return;
      final serverSheet = serverResponse?['sheet'];
      final syncDetail = serverSheet != null
          ? 'Server saved to $serverSheet.'
          : syncError != null
              ? 'Sync failed: $syncError'
              : blockedActivity != null
                  ? 'Sync stopped at $blockedActivity'
                  : offline
                      ? 'Device reports no internet connection.'
                      : 'Saved locally; this visit is still waiting to sync.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${widget.type} • $entityId • ${widget.category}. $syncDetail')));
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => finishing = false);
    }
  }

  @override
  void dispose() {
    purpose.dispose();
    outcome.dispose();
    remarks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WillPopScope(
        onWillPop: () async {
          if (visitStarted) {
            await _backFromVisit();
            return false;
          }
          return true;
        },
        child: Scaffold(
          appBar: AppBar(
              title: Text(widget.category == 'Field Visit'
                  ? '${widget.type} Visit'
                  : widget.category)),
          body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                Card(
                    child: ListTile(
                        leading:
                            const CircleAvatar(child: Icon(Icons.location_on)),
                        title: Text(entityName,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            '${widget.type} • $entityId${villageTown.isEmpty ? '' : ' • $villageTown'}'))),
                const SizedBox(height: 12),
                if (!visitStarted)
                  Card(
                      color: Colors.white,
                      child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(children: [
                            Icon(Icons.play_circle_outline),
                            SizedBox(width: 12),
                            Expanded(
                                child: Text(
                                    'Ready to start. Tap Start Visit when you reach the entity.'))
                          ]))),
                if (visitStarted) ...[
                  Card(
                      color: const Color(0xFFE8F5E9),
                      child: ListTile(
                          leading:
                              const Icon(Icons.timer, color: Color(0xFF0B6E4F)),
                          title: const Text('Visit active',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              'Started ${TimeOfDay.fromDateTime(start).format(context)}'))),
                  const SizedBox(height: 12),
                  TextField(
                      controller: purpose,
                      onChanged: (_) => _persistActive(),
                      decoration: const InputDecoration(labelText: 'Purpose')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: outcome,
                      onChanged: (_) => _persistActive(),
                      decoration: const InputDecoration(labelText: 'Outcome')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: remarks,
                      onChanged: (_) => _persistActive(),
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Remarks')),
                  const SizedBox(height: 16),
                  Card(
                      child: Column(children: [
                    ListTile(
                        leading: const Icon(Icons.photo_camera_outlined),
                        title: const Text('Photographs'),
                        subtitle: Text('${photos.length}/3 photos added'),
                        trailing: IconButton(
                            onPressed: addPhoto,
                            icon: const Icon(Icons.add_a_photo))),
                    if (photos.isNotEmpty)
                      SizedBox(
                          height: 90,
                          child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              itemCount: photos.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (_, i) => ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(photos[i],
                                      width: 90,
                                      height: 70,
                                      fit: BoxFit.cover))))
                  ])),
                ],
              ]),
          bottomNavigationBar: SafeArea(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: FilledButton.icon(
                      onPressed: finishing
                          ? null
                          : (visitStarted ? complete : startVisit),
                      icon: Icon(visitStarted
                          ? Icons.stop_circle_outlined
                          : Icons.play_arrow),
                      label: Text(finishing
                          ? 'Saving…'
                          : (visitStarted
                              ? 'End Activity'
                              : 'Start Activity'))))),
        ),
      );
}
