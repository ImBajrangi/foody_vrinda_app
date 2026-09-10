/// Supabase Cloud Database Configuration for Foody Vrinda
/// Unified across Web (foody_vrinda_v3) and Mobile App (foody_vrinda_app)
class SupabaseConfig {
  static const String supabaseUrl = 'https://mrsxliwyqodtwjuyqmts.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1yc3hsaXd5cW9kdHdqdXlxbXRzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg4NzQxMjcsImV4cCI6MjEwNDQ1MDEyN30.UZteyeZ3LtuVpMJoUqZogPKffmSlHN3Hn9fLtis7lBg';

  // Table Names
  static const String shopsTable = 'foody_shops';
  static const String menusTable = 'foody_menus';
  static const String ordersTable = 'foody_orders';
  static const String usersTable = 'foody_users';
  static const String loggedUsersTable = 'foody_logged_users';
  static const String reviewsTable = 'foody_reviews';
  static const String notificationsTable = 'foody_notifications';
  static const String rolesTable = 'foody_roles';
  static const String offersTable = 'foody_offers';
}

