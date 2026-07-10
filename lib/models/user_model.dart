import 'package:hive/hive.dart';

part 'user_model.g.dart';

@HiveType(typeId: 0)
class User extends HiveObject {
  @HiveField(0)
  String userId;

  @HiveField(1)
  String firstName;

  @HiveField(2)
  String? middleName;

  @HiveField(3)
  String lastName;

  @HiveField(4)
  String email;

  @HiveField(5)
  String password;

  @HiveField(6)
  String? schoolName;

  @HiveField(7)
  DateTime createdAt;

  User({
    required this.userId,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.email,
    required this.password,
    this.schoolName,
    required this.createdAt,
  });
}
