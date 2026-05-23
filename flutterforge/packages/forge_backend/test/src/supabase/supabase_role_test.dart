import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:forge_backend/forge_backend.dart';
import 'package:forge_core/forge_core.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}
class MockUser extends Mock implements User {}
class MockUserResponse extends Mock implements UserResponse {}
class FakeUserAttributes extends Fake implements UserAttributes {}

void main() {
  late SupabaseBackend service;
  late MockSupabaseClient mockClient;
  late MockGoTrueClient mockAuth;

  setUpAll(() {
    registerFallbackValue(FakeUserAttributes());
  });

  setUp(() {
    mockClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    when(() => mockClient.auth).thenReturn(mockAuth);
    service = SupabaseBackend(mockClient);
  });

  group('Supabase Role Mapping', () {
    test('should map admin role correctly from metadata', () {
      final mockUser = MockUser();
      when(() => mockUser.id).thenReturn('123');
      when(() => mockUser.email).thenReturn('admin@test.com');
      when(() => mockUser.userMetadata).thenReturn({'role': 'admin'});
      when(() => mockUser.emailConfirmedAt).thenReturn(DateTime.now().toString());
      
      when(() => mockAuth.currentUser).thenReturn(mockUser);

      final userDetails = service.currentUser;
      
      expect(userDetails?.role, ForgeRole.admin);
    });

    test('should map user role correctly from metadata', () {
      final mockUser = MockUser();
      when(() => mockUser.id).thenReturn('456');
      when(() => mockUser.email).thenReturn('user@test.com');
      when(() => mockUser.userMetadata).thenReturn({'role': 'user'});
      when(() => mockUser.emailConfirmedAt).thenReturn(DateTime.now().toString());
      
      when(() => mockAuth.currentUser).thenReturn(mockUser);

      final userDetails = service.currentUser;
      
      expect(userDetails?.role, ForgeRole.user);
    });

    test('should default to user role if metadata is missing', () {
      final mockUser = MockUser();
      when(() => mockUser.id).thenReturn('789');
      when(() => mockUser.email).thenReturn('no-role@test.com');
      when(() => mockUser.userMetadata).thenReturn({});
      when(() => mockUser.emailConfirmedAt).thenReturn(DateTime.now().toString());
      
      when(() => mockAuth.currentUser).thenReturn(mockUser);

      final userDetails = service.currentUser;
      
      expect(userDetails?.role, ForgeRole.user);
    });

    test('should map custom roles correctly', () {
      final mockUser = MockUser();
      when(() => mockUser.id).thenReturn('000');
      when(() => mockUser.email).thenReturn('editor@test.com');
      when(() => mockUser.userMetadata).thenReturn({'role': 'editor'});
      when(() => mockUser.emailConfirmedAt).thenReturn(DateTime.now().toString());
      
      when(() => mockAuth.currentUser).thenReturn(mockUser);

      final userDetails = service.currentUser;
      
      expect(userDetails?.role, const ForgeRole('editor'));
    });

    test('updateCurrentUser should update role in metadata', () async {
      final mockUser = MockUser();
      when(() => mockUser.id).thenReturn('123');
      when(() => mockUser.email).thenReturn('test@test.com');
      when(() => mockUser.userMetadata).thenReturn({'role': 'admin'});
      when(() => mockUser.emailConfirmedAt).thenReturn(DateTime.now().toString());

      final mockResponse = MockUserResponse();
      when(() => mockResponse.user).thenReturn(mockUser);

      when(() => mockAuth.updateUser(any())).thenAnswer((_) async => mockResponse);

      final result = await service.updateCurrentUser(metadata: {'role': 'admin'});

      expect(result.isRight(), true);
      result.fold(
        (l) => fail('Should not be left'),
        (r) => expect(r.role, ForgeRole.admin),
      );

      verify(() => mockAuth.updateUser(any(
            that: isA<UserAttributes>().having((a) => a.data, 'data', {'role': 'admin'}),
          ))).called(1);
    });

    test('signUpWithEmail should include user role in metadata', () async {
      final mockUser = MockUser();
      when(() => mockUser.id).thenReturn('signup_123');
      when(() => mockUser.email).thenReturn('signup@test.com');
      when(() => mockUser.userMetadata).thenReturn({'role': 'user'});
      when(() => mockUser.emailConfirmedAt).thenReturn(null);

      final mockResponse = AuthResponse(user: mockUser);

      when(() => mockAuth.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            data: any(named: 'data'),
          )).thenAnswer((_) async => mockResponse);

      final result = await service.signUpWithEmail(
        email: 'signup@test.com',
        password: 'password123',
      );

      expect(result.isRight(), true);
      result.fold(
        (l) => fail('Should not be left'),
        (r) => expect(r.role, ForgeRole.user),
      );

      verify(() => mockAuth.signUp(
            email: 'signup@test.com',
            password: 'password123',
            data: any(named: 'data', that: containsPair('role', 'user')),
          )).called(1);
    });
  });
}
