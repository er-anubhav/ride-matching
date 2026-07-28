import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rider_app/providers/ui_state_providers.dart';

void main() {
  group('UserProfileNotifier Tests', () {
    test('initial state is correct', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final profile = container.read(userProfileProvider);
      expect(profile.name, 'Anubhav Tripathi');
      expect(profile.phone, '+91 98765 43210');
    });

    test('updateName works correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(userProfileProvider.notifier).updateName('John Doe');
      final profile = container.read(userProfileProvider);
      expect(profile.name, 'John Doe');
    });

    test('updateAvatarUrl works correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const newAvatarUrl = 'https://images.unsplash.com/photo-example';
      container.read(userProfileProvider.notifier).updateAvatarUrl(newAvatarUrl);
      final profile = container.read(userProfileProvider);
      expect(profile.avatarUrl, newAvatarUrl);
    });
  });

  group('WalletNotifier Tests', () {
    test('initial balance is correct', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final wallet = container.read(walletProvider);
      expect(wallet.balance, 345.5);
    });

    test('addMoney and deductMoney modify state correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Add
      container.read(walletProvider.notifier).addMoney(100.0);
      expect(container.read(walletProvider).balance, 445.5);
      expect(container.read(walletProvider).transactions.first, contains('100.00 added'));

      // Deduct
      container.read(walletProvider.notifier).deductMoney(50.0, 'Office Cab');
      expect(container.read(walletProvider).balance, 395.5);
      expect(container.read(walletProvider).transactions.first, contains('50.00 deducted'));
    });
  });

  group('RideBookingNotifier Tests', () {
    test('initial status is idle and has correct default properties', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final booking = container.read(bookingProvider);
      expect(booking.status, RideBookingStatus.idle);
      expect(booking.webSocketStatus, WebSocketStatus.disconnected);
      expect(booking.driverStartLat, isNull);
      expect(booking.driverStartLng, isNull);
    });

    test('startSearch updates status to searching and webSocketStatus to connecting', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(bookingProvider.notifier).startSearch(
        vehicleName: "UrbanPulse Bike",
        driverArrivalEta: "2 min",
        tripDurationEta: "10 min",
        price: 120.0,
      );
      final booking = container.read(bookingProvider);
      expect(booking.status, RideBookingStatus.searching);
      expect(booking.webSocketStatus, WebSocketStatus.connecting);
    });

    test('reset returns state to idle and disconnects websocket', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(bookingProvider.notifier).startSearch(
        vehicleName: "UrbanPulse Bike",
        driverArrivalEta: "2 min",
        tripDurationEta: "10 min",
        price: 120.0,
      );
      container.read(bookingProvider.notifier).reset();
      final booking = container.read(bookingProvider);
      expect(booking.status, RideBookingStatus.idle);
      expect(booking.webSocketStatus, WebSocketStatus.disconnected);
    });

    test('retryConnection updates websocket status to connecting', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(bookingProvider.notifier).retryConnection();
      final booking = container.read(bookingProvider);
      expect(booking.webSocketStatus, WebSocketStatus.connecting);
    });
  });

  group('SosContactsNotifier Tests', () {
    test('initial state and add/remove contact works correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final contacts = container.read(sosContactsProvider);
      expect(contacts.length, 2);
      expect(contacts[0].name, 'Papa (Primary)');

      // Add contact
      container.read(sosContactsProvider.notifier).addContact('Friend', '+91 99999 99999');
      final updated = container.read(sosContactsProvider);
      expect(updated.length, 3);
      expect(updated.last.name, 'Friend');

      // Remove contact
      final removeId = updated.last.id;
      container.read(sosContactsProvider.notifier).removeContact(removeId);
      expect(container.read(sosContactsProvider).length, 2);
    });
  });

  group('PaymentMethodsNotifier Tests', () {
    test('initial state, set default, and add/remove payment methods works correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final methods = container.read(paymentMethodsProvider);
      expect(methods.length, 2);
      expect(methods[0].isDefault, true);

      // Add Card
      container.read(paymentMethodsProvider.notifier).addCard('5555');
      final updated = container.read(paymentMethodsProvider);
      expect(updated.length, 3);
      expect(updated.last.label, 'Card •••• 5555');
      expect(updated.last.isDefault, true);

      // Set default
      final secondId = updated[1].id;
      container.read(paymentMethodsProvider.notifier).setDefault(secondId);
      expect(container.read(paymentMethodsProvider)[1].isDefault, true);
      expect(container.read(paymentMethodsProvider)[2].isDefault, false);

      // Delete method
      final deleteId = updated.last.id;
      container.read(paymentMethodsProvider.notifier).deleteMethod(deleteId);
      expect(container.read(paymentMethodsProvider).length, 2);
    });
  });

  group('SupportTicketsNotifier Tests', () {
    test('initial state and raise ticket works correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final tickets = container.read(supportTicketsProvider);
      expect(tickets.length, 1);
      expect(tickets.first.category, 'Refund Issue');

      // Raise ticket
      container.read(supportTicketsProvider.notifier).raiseTicket('Lost Item', 'Left keys in bike');
      final updated = container.read(supportTicketsProvider);
      expect(updated.length, 2);
      expect(updated.first.category, 'Lost Item');
      expect(updated.first.status, 'Pending');
    });
  });

  group('SearchHistoryNotifier Tests', () {
    test('initial state and add/clear history works correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final history = container.read(searchHistoryProvider);
      expect(history.length, 0);

      // Add search history
      container.read(searchHistoryProvider.notifier).addHistory('Summit Building, Vibhuti Khand', 26.8624, 80.9991);
      container.read(searchHistoryProvider.notifier).addHistory('Phoenix United Mall, Alambagh', 26.7992, 80.8988);
      final updated = container.read(searchHistoryProvider);
      expect(updated.length, 2);

      // Remove single search item
      container.read(searchHistoryProvider.notifier).removeHistory('Summit Building, Vibhuti Khand');
      expect(container.read(searchHistoryProvider).length, 1);
      expect(container.read(searchHistoryProvider).first.address, 'Phoenix United Mall, Alambagh');

      // Clear history
      container.read(searchHistoryProvider.notifier).clearHistory();
      expect(container.read(searchHistoryProvider).length, 0);
    });
  });

  group('BookmarksNotifier Tests', () {
    test('initial state and add/remove bookmark works correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final bookmarks = container.read(bookmarksProvider);
      expect(bookmarks.length, 0);

      // Add bookmark
      container.read(bookmarksProvider.notifier).addBookmark('Gym', 'Fit Gym, Alambagh', 26.8200, 80.9100);
      final updated = container.read(bookmarksProvider);
      expect(updated.length, 1);
      expect(updated.last.label, 'Gym');

      // Remove bookmark
      final removeAddress = updated.last.address;
      container.read(bookmarksProvider.notifier).removeBookmark(removeAddress);
      expect(container.read(bookmarksProvider).length, 0);
    });
  });

  group('TripHistoryNotifier and completeRide Integration Tests', () {
    test('initial trip history list has 4 elements', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final history = container.read(tripHistoryProvider);
      expect(history.length, 4);
    });

    test('completeRide appends new trip to history', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Start search and match driver, start ride
      container.read(bookingProvider.notifier).startSearch(
        vehicleName: "UrbanPulse Bike",
        driverArrivalEta: "2 min",
        tripDurationEta: "10 min",
        price: 120.0,
      );
      container.read(bookingProvider.notifier).matchDriver();
      container.read(bookingProvider.notifier).startRide();

      final beforeCount = container.read(tripHistoryProvider).length;

      // Complete ride
      container.read(bookingProvider.notifier).completeRide();

      final afterHistory = container.read(tripHistoryProvider);
      expect(afterHistory.length, beforeCount + 1);
      expect(afterHistory.first['vehicle'], 'UrbanPulse Bike');
      expect(afterHistory.first['price'], 120.0);
    });
  });
}
