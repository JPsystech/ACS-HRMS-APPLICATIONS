class BirthdayEmployeeDto {
  BirthdayEmployeeDto({
    required this.employeeId,
    required this.name,
    this.department,
    this.empCode,
    this.profilePhotoUrl,
    this.dob,
    this.birthdayDate,
    this.wishStatus,
  });

  final String employeeId;
  final String name;
  final String? department;
  final String? empCode;
  final String? profilePhotoUrl;
  final String? dob;
  final String? birthdayDate;
  final String? wishStatus;

  static BirthdayEmployeeDto fromJson(Map<String, dynamic> m) {
    return BirthdayEmployeeDto(
      employeeId: (m['employee_id'] ?? m['id']).toString(),
      name: (m['name'] ?? '').toString(),
      department: m['department']?.toString(),
      empCode: m['emp_code']?.toString(),
      profilePhotoUrl: m['profile_photo_url']?.toString(),
      dob: m['dob']?.toString(),
      birthdayDate: m['birthday_date']?.toString(),
      wishStatus: m['wish_status']?.toString(),
    );
  }
}

class GreetingDto {
  GreetingDto({
    required this.id,
    this.greetingImageUrl,
    this.greetingMessage,
    this.wishSentAt,
    this.wishSentBy,
  });

  final String id;
  final String? greetingImageUrl;
  final String? greetingMessage;
  final String? wishSentAt;
  final String? wishSentBy;

  static GreetingDto fromJson(Map<String, dynamic> m) {
    return GreetingDto(
      id: (m['id'] ?? '').toString(),
      greetingImageUrl: m['greeting_image_url']?.toString(),
      greetingMessage: m['greeting_message']?.toString(),
      wishSentAt: m['wish_sent_at']?.toString(),
      wishSentBy: m['wish_sent_by']?.toString(),
    );
  }
}

class WishDto {
  WishDto({
    this.id,
    required this.senderId,
    this.senderName,
    this.message,
    this.createdAt,
    this.replyMessage,
    this.repliedAt,
  });

  final String? id;
  final String senderId;
  final String? senderName;
  final String? message;
  final String? createdAt;
  final String? replyMessage;
  final String? repliedAt;

  static WishDto fromJson(Map<String, dynamic> m) {
    return WishDto(
      id: m['id']?.toString(),
      senderId: (m['sender_id'] ?? '').toString(),
      senderName: m['sender_name']?.toString(),
      message: m['message']?.toString(),
      createdAt: m['created_at']?.toString(),
      replyMessage: m['reply_message']?.toString(),
      repliedAt: m['replied_at']?.toString(),
    );
  }
}
