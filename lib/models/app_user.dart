import 'user_plan.dart';

/// User { uid, plan(free/pro), createdAt }
class AppUser {
  final String uid;
  final UserPlan plan;
  final DateTime createdAt;

  const AppUser({
    required this.uid,
    required this.plan,
    required this.createdAt,
  });

  AppUser copyWith({UserPlan? plan}) => AppUser(
        uid: uid,
        plan: plan ?? this.plan,
        createdAt: createdAt,
      );

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        uid: json['uid'] as String,
        plan: UserPlan.values.firstWhere(
          (e) => e.name == json['plan'],
          orElse: () => UserPlan.free,
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'plan': plan.name,
        'createdAt': createdAt.toIso8601String(),
      };
}
