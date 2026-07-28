import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:driver_app/providers/driver_state_providers.dart';

void main() {
  group('DriverStateNotifier Tests', () {
    late DriverStateNotifier notifier;

    setUp(() {
      WidgetsFlutterBinding.ensureInitialized();
      notifier = DriverStateNotifier();
    });

    test('Initial state is correct', () {
      expect(notifier.state.dutyStatus, DriverDutyStatus.offline);
      expect(notifier.state.kycStatus, KycStatus.notStarted);
      expect(notifier.state.driverLat, 26.8500);
      expect(notifier.state.driverLng, 80.9400);
      expect(notifier.state.earnings, 0.0);
      expect(notifier.state.tripsCompletedCount, 0);
    });

    test('KYC flow transitions state correctly', () {
      notifier.setVehicleDetails("Maruti", "Swift", "UP32-AB-9999");
      expect(notifier.state.vehicleMake, "Maruti");
      expect(notifier.state.vehicleModel, "Swift");
      expect(notifier.state.vehicleNumber, "UP32-AB-9999");
      expect(notifier.state.kycStatus, KycStatus.docsPending);

      notifier.submitKycDocuments();
      expect(notifier.state.kycStatus, KycStatus.underReview);

      notifier.approveKyc();
      expect(notifier.state.kycStatus, KycStatus.approved);

      notifier.updateUpiId("driver@upi");
      expect(notifier.state.upiId, "driver@upi");
    });

    test('Receive and decline incoming ride request', () {
      notifier.receiveIncomingRequest(
        riderName: "Anubhav Tripathi",
        riderPhone: "+91 91234 56789",
        pickupAddress: "India Gate, Rajpath, New Delhi",
        dropoffAddress: "Connaught Place, New Delhi",
        pickupLat: 28.6129,
        pickupLng: 77.2295,
        dropoffLat: 28.6315,
        dropoffLng: 77.2167,
        price: 350.0,
        otp: "4820",
      );

      expect(notifier.state.dutyStatus, DriverDutyStatus.incomingRequest);
      expect(notifier.state.riderName, "Anubhav Tripathi");
      expect(notifier.state.price, 350.0);
      expect(notifier.state.otp, "4820");

      notifier.declineRide();
      expect(notifier.state.dutyStatus, DriverDutyStatus.online);
      expect(notifier.state.riderName, isNull);
    });

    test('Accept ride and arrive at pickup location', () async {
      notifier.receiveIncomingRequest(
        riderName: "Anubhav Tripathi",
        riderPhone: "+91 91234 56789",
        pickupAddress: "India Gate, Rajpath, New Delhi",
        dropoffAddress: "Connaught Place, New Delhi",
        pickupLat: 28.6129,
        pickupLng: 77.2295,
        dropoffLat: 28.6315,
        dropoffLng: 77.2167,
        price: 350.0,
        otp: "4820",
      );

      // acceptRide starts timers and http requests. We will call direct transition test.
      notifier.arriveAtPickup();
      expect(notifier.state.dutyStatus, DriverDutyStatus.arrivedAtPickup);
    });

    test('Start trip with incorrect and correct OTP', () async {
      notifier.receiveIncomingRequest(
        riderName: "Anubhav Tripathi",
        riderPhone: "+91 91234 56789",
        pickupAddress: "India Gate, Rajpath, New Delhi",
        dropoffAddress: "Connaught Place, New Delhi",
        pickupLat: 28.6129,
        pickupLng: 77.2295,
        dropoffLat: 28.6315,
        dropoffLng: 77.2167,
        price: 350.0,
        otp: "4820",
      );

      // Incorrect OTP should fail
      final resultFail = await notifier.startTrip("1111");
      expect(resultFail, isFalse);
      expect(notifier.state.otpInputError, isNotNull);
      expect(notifier.state.dutyStatus, isNot(DriverDutyStatus.tripInProgress));

      // Correct OTP should succeed
      final resultSuccess = await notifier.startTrip("4820");
      expect(resultSuccess, isTrue);
      expect(notifier.state.otpInputError, isNull);
      expect(notifier.state.dutyStatus, DriverDutyStatus.tripInProgress);
    });

    test('End trip updates earnings and history', () {
      notifier.receiveIncomingRequest(
        riderName: "Anubhav Tripathi",
        riderPhone: "+91 91234 56789",
        pickupAddress: "India Gate, Rajpath, New Delhi",
        dropoffAddress: "Connaught Place, New Delhi",
        pickupLat: 28.6129,
        pickupLng: 77.2295,
        dropoffLat: 28.6315,
        dropoffLng: 77.2167,
        price: 350.0,
        otp: "4820",
      );

      notifier.endTrip();
      expect(notifier.state.dutyStatus, DriverDutyStatus.tripCompleted);
      expect(notifier.state.earnings, 350.0 * 0.82);
      expect(notifier.state.tripsCompletedCount, 1);
      expect(notifier.state.earningsHistory.length, 1);

      notifier.resetToOnline();
      expect(notifier.state.dutyStatus, DriverDutyStatus.online);
      expect(notifier.state.riderName, isNull);
    });
  });
}
