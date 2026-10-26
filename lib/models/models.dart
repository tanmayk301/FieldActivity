class UserProfile {
  final String userId;
  final String employeeCode;
  final String name;
  final String email;
  final String mobile;
  final String zone;
  final String region;
  final String territory;
  final String state;
  final String district;

  UserProfile({
    required this.userId,
    required this.employeeCode,
    required this.name,
    required this.email,
    required this.mobile,
    required this.zone,
    required this.region,
    required this.territory,
    required this.state,
    required this.district,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    userId: '${j['User_ID'] ?? ''}',
    employeeCode: '${j['Employee_Code'] ?? ''}',
    name: '${j['Name'] ?? ''}',
    email: '${j['Email'] ?? ''}',
    mobile: '${j['Mobile'] ?? ''}',
    zone: '${j['Zone'] ?? ''}',
    region: '${j['Region'] ?? ''}',
    territory: '${j['Territory'] ?? ''}',
    state: '${j['State'] ?? ''}',
    district: '${j['District'] ?? ''}',
  );
}

class EntityRecord {
  final String id;
  final String name;
  final String mobile;
  final String address;
  final String villageTown;
  final String distributorId;
  final String retailerId;
  final String district;
  final String territory;

  EntityRecord({
    required this.id,
    required this.name,
    this.mobile = '',
    this.address = '',
    this.villageTown = '',
    this.distributorId = '',
    this.retailerId = '',
    this.district = '',
    this.territory = '',
  });

  factory EntityRecord.fromJson(Map<String, dynamic> j, String type) {
    final idKey = type == 'Distributor'
        ? 'Distributor_ID'
        : type == 'Retailer'
            ? 'Retailer_ID'
            : 'Farmer_ID';
    final nameKey = type == 'Distributor'
        ? 'Distributor_Name'
        : type == 'Retailer'
            ? 'Retailer_Name'
            : 'Farmer_Name';
    return EntityRecord(
      id: '${j[idKey] ?? ''}',
      name: '${j[nameKey] ?? ''}',
      mobile: '${j['Mobile'] ?? ''}',
      address: '${j['Address'] ?? ''}',
      villageTown: '${j['Village_Town'] ?? j['Village'] ?? ''}',
      distributorId: '${j['Distributor_ID'] ?? ''}',
      retailerId: '${j['Retailer_ID'] ?? ''}',
      district: '${j['District'] ?? ''}',
      territory: '${j['Territory'] ?? ''}',
    );
  }
}
