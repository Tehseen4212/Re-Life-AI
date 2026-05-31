class UserProfile {
  final String id;
  final String email;
  final String role; // 'store_owner', 'ngo', or '' if not selected
  final String? storeName;
  final String? contactNumber;
  final String? locationAddress;
  final String? googleMapUrl;
  final String? aboutStore;
  final String? avatarUrl;

  UserProfile({
    required this.id,
    required this.email,
    required this.role,
    this.storeName,
    this.contactNumber,
    this.locationAddress,
    this.googleMapUrl,
    this.aboutStore,
    this.avatarUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? '',
      storeName: json['store_name'] as String?,
      contactNumber: json['contact_number'] as String?,
      locationAddress: json['location_address'] as String?,
      googleMapUrl: json['google_map_url'] as String?,
      aboutStore: json['about_store'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'store_name': storeName,
      'contact_number': contactNumber,
      'location_address': locationAddress,
      'google_map_url': googleMapUrl,
      'about_store': aboutStore,
      'avatar_url': avatarUrl,
    };
  }
}
