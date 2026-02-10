import 'package:cloud_firestore/cloud_firestore.dart';

enum UserType { admin, call, accounts, debtCollection, callManager }

class UserModel {
  final String id;
  final String username;
  final String email;
  final UserType userType;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.userType,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      username: data['username'] ?? '',
      email: data['email'] ?? '',
      userType: _parseUserType(data['userType']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  static UserType _parseUserType(dynamic type) {
    switch (type?.toString()) {
      case 'call':
        return UserType.call;
      case 'accounts':
        return UserType.accounts;
      case 'debtCollection':
        return UserType.debtCollection;
      case 'callManager':
        return UserType.callManager;
      case 'admin':
      default:
        return UserType.admin;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'username': username,
      'email': email,
      'userType': userType.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

class WorkRequest {
  final String id;
  final String requestedBy;
  final String customerName;
  final DateTime serviceFrom;
  final DateTime serviceTo;
  final double initialAmount;
  final String description;
  final WorkRequestStatus status;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? rejectionReason;
  final List<Expense> expenses;

  WorkRequest({
    required this.id,
    required this.requestedBy,
    required this.customerName,
    required this.serviceFrom,
    required this.serviceTo,
    required this.initialAmount,
    required this.description,
    required this.status,
    required this.createdAt,
    this.approvedAt,
    this.approvedBy,
    this.rejectionReason,
    this.expenses = const [],
  });

  factory WorkRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WorkRequest(
      id: doc.id,
      requestedBy: data['requestedBy'] ?? '',
      customerName: data['customerName'] ?? '',
      serviceFrom: (data['serviceFrom'] as Timestamp).toDate(),
      serviceTo: (data['serviceTo'] as Timestamp).toDate(),
      initialAmount: (data['initialAmount'] ?? 0).toDouble(),
      description: data['description'] ?? '',
      status: _parseRequestStatus(data['status']),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      approvedBy: data['approvedBy'],
      rejectionReason: data['rejectionReason'],
      expenses:
          (data['expenses'] as List<dynamic>?)
              ?.map((e) => Expense.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  static WorkRequestStatus _parseRequestStatus(dynamic status) {
    switch (status) {
      case 'pending':
        return WorkRequestStatus.pending;
      case 'approved':
        return WorkRequestStatus.approved;
      case 'rejected':
        return WorkRequestStatus.rejected;
      default:
        return WorkRequestStatus.pending;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'requestedBy': requestedBy,
      'customerName': customerName,
      'serviceFrom': Timestamp.fromDate(serviceFrom),
      'serviceTo': Timestamp.fromDate(serviceTo),
      'initialAmount': initialAmount,
      'description': description,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
      if (approvedBy != null) 'approvedBy': approvedBy,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      'expenses': expenses.map((e) => e.toMap()).toList(),
    };
  }

  double get totalExpenses {
    return expenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }
}

enum WorkRequestStatus { pending, approved, rejected }

class Expense {
  final String id;
  final ExpenseType type;
  final double amount;
  final String description;
  final DateTime date;
  final String? receiptBase64;

  Expense({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    this.receiptBase64,
  });

  factory Expense.fromMap(Map<String, dynamic> data) {
    return Expense(
      id: data['id'] ?? '',
      type: _parseExpenseType(data['type']),
      amount: (data['amount'] ?? 0).toDouble(),
      description: data['description'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      receiptBase64: data['receiptBase64'],
    );
  }

  static ExpenseType _parseExpenseType(dynamic type) {
    switch (type) {
      case 'flight':
        return ExpenseType.flight;
      case 'hotel':
        return ExpenseType.hotel;
      case 'meal':
        return ExpenseType.meal;
      case 'train':
        return ExpenseType.train;
      case 'bus':
        return ExpenseType.bus;
      case 'cab':
        return ExpenseType.cab;
      case 'auto':
        return ExpenseType.auto;
      case 'transport': // Legacy support
        return ExpenseType.cab; // Default legacy transport to cab
      case 'other':
        return ExpenseType.other;
      default:
        return ExpenseType.other;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'amount': amount,
      'description': description,
      'date': Timestamp.fromDate(date),
      if (receiptBase64 != null) 'receiptBase64': receiptBase64,
    };
  }
}

enum ExpenseType { flight, hotel, meal, train, bus, cab, auto, other }

enum CallRequestStatus {
  pendingApproval,
  approved,
  rejected,
  pendingCredit,
  draft,
  pendingReport,
  completed,
  poPending,
  pendingInvoice,
  invoiceCreated,
}

class CallRequest {
  final String id;
  final String requestedBy;
  final String customerName;
  final DateTime callFromDate;
  final DateTime callToDate;
  final double requestedAmount;
  final double? approvedAmount;
  final String notes;
  final String? completionNotes;
  final String? completionNotesUpdatedBy;
  final DateTime? completionNotesUpdatedAt;
  final CallRequestStatus status;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? rejectionReason;
  final bool isCredited;
  final DateTime? creditedAt;
  final String? creditedBy;
  final List<Expense> expenses;
  final String? reportScreenshotBase64;
  final String? poNumber;
  final String? piNumber;
  final String? poGivenBy;
  final String? piGivenBy;
  final String? invoiceCreatedBy;
  final List<Map<String, dynamic>> followUps;
  final DateTime? pendingReportDueDate;
  final Map<String, dynamic>? dueDateExtensionRequest;
  final Map<String, dynamic>? additionalExpenseRequest;
  final List<Map<String, dynamic>>? durationExtensionHistory;

  CallRequest({
    required this.id,
    required this.requestedBy,
    required this.customerName,
    required this.callFromDate,
    required this.callToDate,
    required this.requestedAmount,
    this.approvedAmount,
    required this.notes,
    this.completionNotes,
    this.completionNotesUpdatedBy,
    this.completionNotesUpdatedAt,
    required this.status,
    required this.createdAt,
    this.approvedAt,
    this.approvedBy,
    this.rejectionReason,
    this.isCredited = false,
    this.creditedAt,
    this.creditedBy,
    this.expenses = const [],
    this.reportScreenshotBase64,
    this.poNumber,
    this.piNumber,
    this.poGivenBy,
    this.piGivenBy,
    this.invoiceCreatedBy,
    this.followUps = const [],
    this.pendingReportDueDate,
    this.dueDateExtensionRequest,
    this.additionalExpenseRequest,
    this.durationExtensionHistory,
  });

  factory CallRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CallRequest(
      id: doc.id,
      requestedBy: data['requestedBy'] ?? '',
      customerName: data['customerName'] ?? '',
      callFromDate: (data['callFromDate'] as Timestamp).toDate(),
      callToDate: (data['callToDate'] as Timestamp).toDate(),
      requestedAmount: (data['requestedAmount'] ?? 0).toDouble(),
      approvedAmount: data['approvedAmount']?.toDouble(),
      notes: data['notes'] ?? '',
      completionNotes: data['completionNotes']?.toString(),
      completionNotesUpdatedBy: data['completionNotesUpdatedBy']?.toString(),
      completionNotesUpdatedAt: (data['completionNotesUpdatedAt'] as Timestamp?)
          ?.toDate(),
      status: _parseCallRequestStatus(data['status']),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      approvedBy: data['approvedBy'],
      rejectionReason: data['rejectionReason'],
      isCredited: data['isCredited'] ?? false,
      creditedAt: (data['creditedAt'] as Timestamp?)?.toDate(),
      creditedBy: data['creditedBy'],
      expenses:
          (data['expenses'] as List<dynamic>?)
              ?.map((e) => Expense.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      reportScreenshotBase64: data['reportScreenshotBase64'],
      poNumber: data['poNumber'],
      piNumber: data['piNumber'],
      poGivenBy: data['poGivenBy'],
      piGivenBy: data['piGivenBy'],
      invoiceCreatedBy: data['invoiceCreatedBy'],
      followUps:
          (data['followUps'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      pendingReportDueDate: (data['pendingReportDueDate'] as Timestamp?)
          ?.toDate(),
      dueDateExtensionRequest:
          data['dueDateExtensionRequest'] as Map<String, dynamic>?,
      additionalExpenseRequest:
          data['additionalExpenseRequest'] as Map<String, dynamic>?,
      durationExtensionHistory:
          (data['durationExtensionHistory'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
    );
  }

  static CallRequestStatus _parseCallRequestStatus(dynamic status) {
    switch (status) {
      case 'pendingApproval':
        return CallRequestStatus.pendingApproval;
      case 'approved':
        return CallRequestStatus.approved;
      case 'rejected':
        return CallRequestStatus.rejected;
      case 'pendingCredit':
        return CallRequestStatus.pendingCredit;
      case 'draft':
        return CallRequestStatus.draft;
      case 'pendingReport':
        return CallRequestStatus.pendingReport;
      case 'completed':
        return CallRequestStatus.completed;
      case 'poPending':
        return CallRequestStatus.poPending;
      case 'pendingInvoice':
        return CallRequestStatus.pendingInvoice;
      case 'invoiceCreated':
        return CallRequestStatus.invoiceCreated;
      default:
        return CallRequestStatus.pendingApproval;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'requestedBy': requestedBy,
      'customerName': customerName,
      'callFromDate': Timestamp.fromDate(callFromDate),
      'callToDate': Timestamp.fromDate(callToDate),
      'requestedAmount': requestedAmount,
      if (approvedAmount != null) 'approvedAmount': approvedAmount,
      'notes': notes,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
      if (approvedBy != null) 'approvedBy': approvedBy,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      'isCredited': isCredited,
      if (creditedAt != null) 'creditedAt': Timestamp.fromDate(creditedAt!),
      if (creditedBy != null) 'creditedBy': creditedBy,
      'expenses': expenses.map((e) => e.toMap()).toList(),
      if (reportScreenshotBase64 != null)
        'reportScreenshotBase64': reportScreenshotBase64,
      if (poNumber != null) 'poNumber': poNumber,
      if (piNumber != null) 'piNumber': piNumber,
      if (poGivenBy != null) 'poGivenBy': poGivenBy,
      if (piGivenBy != null) 'piGivenBy': piGivenBy,
      if (invoiceCreatedBy != null) 'invoiceCreatedBy': invoiceCreatedBy,
      if (followUps.isNotEmpty) 'followUps': followUps,
      if (pendingReportDueDate != null)
        'pendingReportDueDate': Timestamp.fromDate(pendingReportDueDate!),
      if (dueDateExtensionRequest != null)
        'dueDateExtensionRequest': dueDateExtensionRequest,
      if (additionalExpenseRequest != null)
        'additionalExpenseRequest': additionalExpenseRequest,
      if (durationExtensionHistory != null &&
          durationExtensionHistory!.isNotEmpty)
        'durationExtensionHistory': durationExtensionHistory,
    };
  }

  double get finalAmount {
    double baseAmount = approvedAmount ?? requestedAmount;

    // Add additional expense amount if present
    if (additionalExpenseRequest != null) {
      final additionalAmount = (additionalExpenseRequest!['amount'] ?? 0)
          .toDouble();
      baseAmount += additionalAmount;
    }

    return baseAmount;
  }

  int get durationInDays {
    return callToDate.difference(callFromDate).inDays + 1;
  }

  String get durationText {
    final duration = callToDate.difference(callFromDate);
    if (duration.inDays == 0) {
      return 'Same day';
    } else if (duration.inDays == 1) {
      return '2 days';
    } else {
      return '${duration.inDays + 1} days';
    }
  }

  // Helper method to load report screenshot from separate collection
  Future<String?> loadReportScreenshot() async {
    final images = await UserService.getExpenseImages(
      callRequestId: id,
      imageType: 'report',
    );
    return images.isNotEmpty ? images.first : null;
  }

  // Helper method to load all report screenshots
  Future<List<String>> loadReportScreenshots() async {
    return await UserService.getExpenseImages(
      callRequestId: id,
      imageType: 'report',
    );
  }

  // Helper method to load receipt images
  Future<List<String>> loadReceiptImages() async {
    return await UserService.getExpenseImages(
      callRequestId: id,
      imageType: 'receipt',
    );
  }

  // Helper method to get expenses with receipt images loaded
  Future<List<Expense>> loadExpensesWithReceipts() async {
    if (expenses.isEmpty) return expenses;

    final receiptImages = await loadReceiptImages();
    final expensesWithReceipts = <Expense>[];

    for (int i = 0; i < expenses.length; i++) {
      final expense = expenses[i];
      final receiptBase64 = i < receiptImages.length ? receiptImages[i] : null;

      expensesWithReceipts.add(
        Expense(
          id: expense.id,
          type: expense.type,
          amount: expense.amount,
          description: expense.description,
          date: expense.date,
          receiptBase64: receiptBase64,
        ),
      );
    }

    return expensesWithReceipts;
  }
}

class UserService {
  // Update call status generically
  static Future<void> updateCallStatus(
    String callId,
    CallRequestStatus status,
  ) async {
    print('DEBUG: updateCallStatus called with status: ${status.name}');

    Map<String, dynamic> updateData = {
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // If changing to pendingReport, set due date to 7 days from now
    if (status == CallRequestStatus.pendingReport) {
      final dueDate = DateTime.now().add(Duration(days: 7));
      print('DEBUG: Setting pendingReportDueDate to: $dueDate');
      updateData['pendingReportDueDate'] = Timestamp.fromDate(dueDate);
    }

    print('DEBUG: Update data: $updateData');
    await _firestore.collection('call_requests').doc(callId).update(updateData);
    print('DEBUG: Status update completed for callId: $callId');
  }

  // Add a follow-up entry to a call
  static Future<void> addCallFollowUp({
    required String callId,
    required Map<String, dynamic> followUp,
  }) async {
    final docRef = _firestore.collection('call_requests').doc(callId);
    await docRef.update({
      'followUps': FieldValue.arrayUnion([followUp]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Fetch follow-ups for a call (returns the list, or empty if none)
  static Future<List<Map<String, dynamic>>> getCallFollowUps(
    String callId,
  ) async {
    final doc = await _firestore.collection('call_requests').doc(callId).get();
    final data = doc.data();
    if (data == null || data['followUps'] == null) return [];
    return (data['followUps'] as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  // Save PO/PI and update status for a call
  static Future<void> savePOPIAndUpdateStatus({
    required String callId,
    required String type, // 'PO' or 'PI'
    required String number,
    String? givenBy,
  }) async {
    final update = <String, dynamic>{};
    if (type == 'PO') {
      update['poNumber'] = number;
      if (givenBy != null) update['poGivenBy'] = givenBy;
      update['status'] = 'pendingInvoice';
    } else {
      update['piNumber'] = number;
      if (givenBy != null) update['piGivenBy'] = givenBy;
      update['status'] = 'poPending';
    }
    await _firestore.collection('call_requests').doc(callId).update(update);
  }

  // Mark invoice as created and store who created it
  static Future<void> markInvoiceCreated({
    required String callId,
    required String createdBy,
  }) async {
    await _firestore.collection('call_requests').doc(callId).update({
      'status': 'invoiceCreated',
      'invoiceCreatedBy': createdBy,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get call requests for debtCollection team: only completed and PO pending
  static Stream<List<CallRequest>> getCallRequestsForDebtCollection(
    String username,
  ) {
    return _firestore
        .collection('call_requests')
        .where('status', whereIn: ['completed', 'poPending'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CallRequest.fromFirestore(doc))
              .toList(),
        );
  }

  // Complete call request: set status and optionally upload report screenshot
  static Future<void> completeCallRequest({
    required String requestId,
    required bool sentReport,
    String? reportScreenshotBase64,
  }) async {
    final update = <String, dynamic>{'status': 'completed'};

    // Store report screenshot in separate collection if provided
    if (reportScreenshotBase64 != null) {
      await storeExpenseImages(
        callRequestId: requestId,
        imageBase64List: [reportScreenshotBase64],
        imageType: 'report',
      );
    }

    await _firestore.collection('call_requests').doc(requestId).update(update);
  }

  // Update report for completed call request
  static Future<void> updateCallReport({
    required String requestId,
    required String reportScreenshotBase64,
  }) async {
    // Store report screenshot in separate collection
    await updateExpenseImages(
      callRequestId: requestId,
      imageBase64List: [reportScreenshotBase64],
      imageType: 'report',
    );

    await _firestore.collection('call_requests').doc(requestId).update({
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateCompletionNotes({
    required String requestId,
    required String notes,
    required String updatedBy,
  }) async {
    await _firestore.collection('call_requests').doc(requestId).update({
      'completionNotes': notes,
      'completionNotesUpdatedBy': updatedBy,
      'completionNotesUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Update expenses for a call request
  static Future<void> updateCallRequestExpenses(
    String requestId,
    List<Expense> expenses,
  ) async {
    print(
      'DEBUG: updateCallRequestExpenses called for $requestId with ${expenses.length} expenses',
    );
    print(
      'DEBUG: Receipt images in expenses: ${expenses.where((e) => e.receiptBase64 != null && e.receiptBase64!.isNotEmpty).length}',
    );
    // Collect all receipt images
    final receiptImages = <String>[];
    for (final expense in expenses) {
      if (expense.receiptBase64 != null && expense.receiptBase64!.isNotEmpty) {
        receiptImages.add(expense.receiptBase64!);
      }
    }

    // Only update images if we have new receipt images
    // This prevents accidental deletion of existing images when expenses are updated
    // without receipt images loaded (e.g., from Firestore documents)
    if (receiptImages.isNotEmpty) {
      await updateExpenseImages(
        callRequestId: requestId,
        imageBase64List: receiptImages,
        imageType: 'receipt',
      );
    } else {
      // Check if we should preserve existing images
      // If expenses have no receipt data but there are existing images, don't delete them
      final existingImages = await getExpenseImages(
        callRequestId: requestId,
        imageType: 'receipt',
      );

      // If there are existing images but no new images in the update,
      // this might be an update that doesn't involve images, so preserve existing ones
      if (existingImages.isNotEmpty) {
        print('Preserving existing receipt images during expense update');
        // Don't call updateExpenseImages to avoid deleting existing images
      }
    }

    // Store expenses without the base64 data (since it's now in separate collection)
    final expensesWithoutImages = expenses
        .map(
          (e) => {
            'id': e.id,
            'type': e.type.name,
            'amount': e.amount,
            'description': e.description,
            'date': Timestamp.fromDate(e.date),
            // Remove receiptBase64 from main document
          },
        )
        .toList();

    await _firestore.collection('call_requests').doc(requestId).update({
      'expenses': expensesWithoutImages,
    });
  }

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get user by username
  static Future<UserModel?> getUserByUsername(String username) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      return UserModel.fromFirestore(query.docs.first);
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  // Create work request
  static Future<String?> createWorkRequest(WorkRequest request) async {
    try {
      final docRef = await _firestore
          .collection('work_requests')
          .add(request.toFirestore());
      return docRef.id;
    } catch (e) {
      print('Error creating work request: $e');
      return null;
    }
  }

  // Get work requests for admin (all requests)
  static Stream<List<WorkRequest>> getWorkRequestsForAdmin() {
    return _firestore
        .collection('work_requests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => WorkRequest.fromFirestore(doc))
              .toList(),
        );
  }

  // Get work requests for call user (only their requests)
  static Stream<List<WorkRequest>> getWorkRequestsForUser(String username) {
    return _firestore
        .collection('work_requests')
        .where('requestedBy', isEqualTo: username)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => WorkRequest.fromFirestore(doc))
              .toList(),
        );
  }

  // Get single work request by ID
  static Stream<WorkRequest?> getWorkRequestById(String requestId) {
    return _firestore
        .collection('work_requests')
        .doc(requestId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return WorkRequest.fromFirestore(doc);
        });
  }

  // Approve work request
  static Future<bool> approveWorkRequest(
    String requestId,
    String approvedBy,
  ) async {
    try {
      await _firestore.collection('work_requests').doc(requestId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': approvedBy,
      });
      return true;
    } catch (e) {
      print('Error approving work request: $e');
      return false;
    }
  }

  // Reject work request
  static Future<bool> rejectWorkRequest(
    String requestId,
    String rejectionReason,
  ) async {
    try {
      await _firestore.collection('work_requests').doc(requestId).update({
        'status': 'rejected',
        'rejectionReason': rejectionReason,
      });
      return true;
    } catch (e) {
      print('Error rejecting work request: $e');
      return false;
    }
  }

  // Add expense to work request
  static Future<bool> addExpenseToWorkRequest(
    String requestId,
    Expense expense,
  ) async {
    try {
      await _firestore.collection('work_requests').doc(requestId).update({
        'expenses': FieldValue.arrayUnion([expense.toMap()]),
      });
      return true;
    } catch (e) {
      print('Error adding expense: $e');
      return false;
    }
  }

  // ==================== CALL REQUEST METHODS ====================

  // Create call request
  static Future<String?> createCallRequest(CallRequest request) async {
    try {
      final docRef = await _firestore
          .collection('call_requests')
          .add(request.toFirestore());
      return docRef.id;
    } catch (e) {
      print('Error creating call request: $e');
      return null;
    }
  }

  // Get call requests for call user (only their requests)
  static Stream<List<CallRequest>> getCallRequestsForUser(String username) {
    return _firestore
        .collection('call_requests')
        .where('requestedBy', isEqualTo: username)
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs
              .map((doc) => CallRequest.fromFirestore(doc))
              .toList();
          // Sort in memory instead of using orderBy in query
          docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return docs;
        });
  }

  // Get call requests for call manager (all requests)
  static Stream<List<CallRequest>> getCallRequestsForManager() {
    return _firestore
        .collection('call_requests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CallRequest.fromFirestore(doc))
              .toList(),
        );
  }

  // Get call requests for accounts team (credit pending requests only)
  static Stream<List<CallRequest>> getCallRequestsForAccounts(String username) {
    return _firestore.collection('call_requests').snapshots().map((snapshot) {
      final docs = snapshot.docs
          .map((doc) => CallRequest.fromFirestore(doc))
          .where(
            (req) =>
                req.status == CallRequestStatus.pendingCredit ||
                (req.isCredited == true && req.creditedBy == username),
          )
          .toList();
      docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return docs;
    });
  }

  // Get single call request by ID
  static Stream<CallRequest?> getCallRequestById(String requestId) {
    return _firestore
        .collection('call_requests')
        .doc(requestId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return CallRequest.fromFirestore(doc);
        });
  }

  // Approve call request (by call manager)
  static Future<bool> approveCallRequest(
    String requestId,
    String approvedBy,
    double? modifiedAmount,
  ) async {
    try {
      Map<String, dynamic> updateData = {
        'status': 'pendingCredit', // Set to pendingCredit instead of approved
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': approvedBy,
      };

      if (modifiedAmount != null) {
        updateData['approvedAmount'] = modifiedAmount;
      }

      await _firestore
          .collection('call_requests')
          .doc(requestId)
          .update(updateData);
      return true;
    } catch (e) {
      print('Error approving call request: $e');
      return false;
    }
  }

  // Reject call request (by call manager)
  static Future<bool> rejectCallRequest(
    String requestId,
    String rejectionReason,
  ) async {
    try {
      await _firestore.collection('call_requests').doc(requestId).update({
        'status': 'rejected',
        'rejectionReason': rejectionReason,
      });
      return true;
    } catch (e) {
      print('Error rejecting call request: $e');
      return false;
    }
  }

  // Mark call as credited (by accounts team)
  static Future<bool> markCallAsCredited(
    String requestId,
    String creditedBy,
  ) async {
    try {
      await _firestore.collection('call_requests').doc(requestId).update({
        'status': 'pendingCredit',
        'isCredited': true,
        'creditedAt': FieldValue.serverTimestamp(),
        'creditedBy': creditedBy,
      });
      return true;
    } catch (e) {
      print('Error marking call as credited: $e');
      return false;
    }
  }

  // Move call to draft (when credited)
  static Future<bool> moveCallToDraft(String requestId) async {
    try {
      await _firestore.collection('call_requests').doc(requestId).update({
        'status': 'draft',
      });
      return true;
    } catch (e) {
      print('Error moving call to draft: $e');
      return false;
    }
  }

  // Check if user has pending call requests
  static Future<bool> hasPendingCallRequests(String username) async {
    try {
      final query = await _firestore
          .collection('call_requests')
          .where('requestedBy', isEqualTo: username)
          .where(
            'status',
            whereIn: ['pendingApproval', 'approved', 'pendingCredit'],
          )
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      print('Error checking pending call requests: $e');
      return false;
    }
  }

  // Request due date extension
  static Future<bool> requestDueDateExtension({
    required String callId,
    required DateTime newDueDate,
    required String reason,
    required String requestedBy,
  }) async {
    try {
      await _firestore.collection('call_requests').doc(callId).update({
        'dueDateExtensionRequest': {
          'newDueDate': Timestamp.fromDate(newDueDate),
          'reason': reason,
          'requestedBy': requestedBy,
          'requestedAt': FieldValue.serverTimestamp(),
          'status': 'pending', // pending, approved, rejected
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error requesting due date extension: $e');
      return false;
    }
  }

  // Request additional expenses
  static Future<bool> requestAdditionalExpenses({
    required String callId,
    required double additionalAmount,
    required String reason,
    required String requestedBy,
  }) async {
    try {
      await _firestore.collection('call_requests').doc(callId).update({
        'additionalExpenseRequest': {
          'amount': additionalAmount,
          'reason': reason,
          'requestedBy': requestedBy,
          'requestedAt': FieldValue.serverTimestamp(),
          'status': 'pending', // pending, approved, rejected
          'approvedAt': null,
          'approvedBy': null,
          'creditedAt': null,
          'creditedBy': null,
        },
        'status': 'pendingApproval', // Change status to pending approval
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error requesting additional expenses: $e');
      return false;
    }
  }

  // Approve/Reject due date extension (by call manager)
  static Future<bool> respondToDueDateExtension({
    required String callId,
    required bool approved,
    required String respondedBy,
    String? rejectionReason,
  }) async {
    try {
      Map<String, dynamic> updateData = {
        'dueDateExtensionRequest.status': approved ? 'approved' : 'rejected',
        'dueDateExtensionRequest.respondedBy': respondedBy,
        'dueDateExtensionRequest.respondedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (approved) {
        // Get the requested due date and update the actual due date
        final doc = await _firestore
            .collection('call_requests')
            .doc(callId)
            .get();
        final data = doc.data();
        if (data != null && data['dueDateExtensionRequest'] != null) {
          final extensionData =
              data['dueDateExtensionRequest'] as Map<String, dynamic>;
          final newDueDate = (extensionData['newDueDate'] as Timestamp)
              .toDate();
          updateData['pendingReportDueDate'] = Timestamp.fromDate(newDueDate);
        }
      } else if (rejectionReason != null) {
        updateData['dueDateExtensionRequest.rejectionReason'] = rejectionReason;
      }

      await _firestore
          .collection('call_requests')
          .doc(callId)
          .update(updateData);
      return true;
    } catch (e) {
      print('Error responding to due date extension: $e');
      return false;
    }
  }

  // Approve/Reject additional expense request (by call manager)
  static Future<bool> respondToAdditionalExpenseRequest({
    required String callId,
    required bool approved,
    required String respondedBy,
    String? rejectionReason,
  }) async {
    try {
      Map<String, dynamic> updateData = {
        'additionalExpenseRequest.status': approved ? 'approved' : 'rejected',
        'additionalExpenseRequest.approvedBy': approved ? respondedBy : null,
        'additionalExpenseRequest.approvedAt': approved
            ? FieldValue.serverTimestamp()
            : null,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (approved) {
        // Get the requested amount and add it to initial amount
        final doc = await _firestore
            .collection('call_requests')
            .doc(callId)
            .get();
        final data = doc.data();
        if (data != null && data['additionalExpenseRequest'] != null) {
          final expenseData =
              data['additionalExpenseRequest'] as Map<String, dynamic>;
          final additionalAmount = (expenseData['amount'] ?? 0).toDouble();
          final initialAmount = (data['requestedAmount'] ?? 0).toDouble();
          updateData['approvedAmount'] = initialAmount + additionalAmount;
          updateData['status'] = 'approved'; // Change status back to approved

          // Mark that additional expense needs separate crediting
          updateData['additionalExpenseRequest.needsCrediting'] = true;
        }
      } else {
        // If rejected, change status back to previous state (draft or approved)
        final doc = await _firestore
            .collection('call_requests')
            .doc(callId)
            .get();
        final data = doc.data();
        if (data != null) {
          // Return to draft status if it was a draft call, otherwise approved
          updateData['status'] = 'draft';
        }
      }

      if (rejectionReason != null) {
        updateData['additionalExpenseRequest.rejectionReason'] =
            rejectionReason;
      }

      await _firestore
          .collection('call_requests')
          .doc(callId)
          .update(updateData);
      return true;
    } catch (e) {
      print('Error responding to additional expense request: $e');
      return false;
    }
  }

  // Credit additional expenses (by accounts team)
  static Future<bool> creditAdditionalExpenses({
    required String callId,
    required String creditedBy,
  }) async {
    try {
      await _firestore.collection('call_requests').doc(callId).update({
        'additionalExpenseRequest.creditedAt': FieldValue.serverTimestamp(),
        'additionalExpenseRequest.creditedBy': creditedBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error crediting additional expenses: $e');
      return false;
    }
  }

  // Extend call duration (automatically updates end date)
  static Future<bool> extendCallDuration({
    required String callId,
    required DateTime newEndDate,
    required String reason,
    required String extendedBy,
  }) async {
    try {
      // First get the current call data to capture the previous end date
      final doc = await _firestore
          .collection('call_requests')
          .doc(callId)
          .get();
      final data = doc.data();
      if (data == null) return false;

      final currentEndDate = (data['callToDate'] as Timestamp).toDate();
      final now = DateTime.now();

      await _firestore.collection('call_requests').doc(callId).update({
        'callToDate': Timestamp.fromDate(newEndDate),
        'durationExtensionHistory': FieldValue.arrayUnion([
          {
            'previousEndDate': Timestamp.fromDate(currentEndDate),
            'newEndDate': Timestamp.fromDate(newEndDate),
            'reason': reason,
            'extendedBy': extendedBy,
            'extendedAt': Timestamp.fromDate(now),
          },
        ]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error extending call duration: $e');
      return false;
    }
  }

  // Store expense images in separate collection with size management
  static Future<bool> storeExpenseImages({
    required String callRequestId,
    required List<String> imageBase64List,
    required String imageType, // 'receipt' or 'report'
  }) async {
    try {
      if (imageBase64List.isEmpty) return true;

      // Calculate size of all images
      final totalSize = imageBase64List.fold<int>(
        0,
        (sum, image) => sum + image.length,
      );

      // Maximum size per document (leaving buffer for other fields)
      const maxSizePerDoc = 800000; // ~800KB to leave room for metadata

      if (totalSize <= maxSizePerDoc) {
        // All images fit in one document
        // Use image type specific document ID to avoid conflicts between receipt and report images
        final mainDocId = '${callRequestId}_${imageType}';
        await _firestore.collection('expense_images').doc(mainDocId).set({
          'callRequestId': callRequestId,
          'imageType': imageType,
          'images': imageBase64List,
          'totalImages': imageBase64List.length,
          'documentIndex': 0,
          'totalDocuments': 1,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        // Split images across multiple documents
        final chunks = <List<String>>[];
        var currentChunk = <String>[];
        var currentSize = 0;

        for (final image in imageBase64List) {
          if (currentSize + image.length > maxSizePerDoc &&
              currentChunk.isNotEmpty) {
            chunks.add(List.from(currentChunk));
            currentChunk.clear();
            currentSize = 0;
          }
          currentChunk.add(image);
          currentSize += image.length;
        }

        if (currentChunk.isNotEmpty) {
          chunks.add(currentChunk);
        }

        // Store each chunk in a separate document
        for (int i = 0; i < chunks.length; i++) {
          final docId = i == 0
              ? '${callRequestId}_${imageType}'
              : '${callRequestId}_${imageType}_$i';
          await _firestore.collection('expense_images').doc(docId).set({
            'callRequestId': callRequestId,
            'imageType': imageType,
            'images': chunks[i],
            'totalImages': imageBase64List.length,
            'documentIndex': i,
            'totalDocuments': chunks.length,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      return true;
    } catch (e) {
      print('Error storing expense images: $e');
      return false;
    }
  }

  // Retrieve all expense images for a call request
  static Future<List<String>> getExpenseImages({
    required String callRequestId,
    required String imageType,
  }) async {
    try {
      print(
        'DEBUG: getExpenseImages called for $callRequestId, type: $imageType',
      );

      // First, get the main document using the new naming convention
      final mainDocId = '${callRequestId}_${imageType}';
      final mainDoc = await _firestore
          .collection('expense_images')
          .doc(mainDocId)
          .get();

      if (!mainDoc.exists) {
        print(
          'DEBUG: No expense_images document found for $mainDocId, checking legacy format',
        );

        // Check for backward compatibility with old document ID format
        final legacyDoc = await _firestore
            .collection('expense_images')
            .doc(callRequestId)
            .get();

        if (legacyDoc.exists) {
          final legacyData = legacyDoc.data()!;
          final legacyImageType = legacyData['imageType'] as String? ?? '';

          if (legacyImageType == imageType) {
            print('DEBUG: Found legacy document with matching image type');

            // Get data from legacy format
            final totalDocuments = legacyData['totalDocuments'] as int? ?? 1;
            final allImages = <String>[];

            // Collect images from all legacy documents
            for (int i = 0; i < totalDocuments; i++) {
              final legacyDocId = i == 0
                  ? callRequestId
                  : '${callRequestId}_$i';
              final doc = await _firestore
                  .collection('expense_images')
                  .doc(legacyDocId)
                  .get();

              if (doc.exists) {
                final data = doc.data()!;
                final images = List<String>.from(data['images'] ?? []);
                allImages.addAll(images);
              }
            }

            print(
              'DEBUG: Retrieved ${allImages.length} images from legacy format',
            );
            return allImages;
          }
        }

        print('DEBUG: No expense_images document found for $mainDocId');
        return [];
      }

      final mainData = mainDoc.data()!;
      final totalDocuments = mainData['totalDocuments'] as int? ?? 1;
      final storedImageType = mainData['imageType'] as String? ?? '';

      print(
        'DEBUG: Found expense_images document - totalDocuments: $totalDocuments, storedImageType: $storedImageType',
      );

      // Check if the image type matches
      if (storedImageType != imageType) {
        print(
          'DEBUG: Image type mismatch - requested: $imageType, stored: $storedImageType',
        );
        return [];
      }

      final allImages = <String>[];

      // Collect images from all documents
      for (int i = 0; i < totalDocuments; i++) {
        final docId = i == 0
            ? '${callRequestId}_${imageType}'
            : '${callRequestId}_${imageType}_$i';
        final doc = await _firestore
            .collection('expense_images')
            .doc(docId)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          final images = List<String>.from(data['images'] ?? []);
          print('DEBUG: Document $docId has ${images.length} images');
          allImages.addAll(images);
        } else {
          print('DEBUG: Document $docId does not exist');
        }
      }

      print('DEBUG: Total images retrieved: ${allImages.length}');
      return allImages;
    } catch (e) {
      print('Error retrieving expense images: $e');
      return [];
    }
  }

  // Update expense images (replaces existing images of the same type)
  static Future<bool> updateExpenseImages({
    required String callRequestId,
    required List<String> imageBase64List,
    required String imageType,
  }) async {
    try {
      // First, delete existing images of this type
      await deleteExpenseImages(
        callRequestId: callRequestId,
        imageType: imageType,
      );

      // Then store the new images
      return await storeExpenseImages(
        callRequestId: callRequestId,
        imageBase64List: imageBase64List,
        imageType: imageType,
      );
    } catch (e) {
      print('Error updating expense images: $e');
      return false;
    }
  }

  // Delete expense images of a specific type
  static Future<bool> deleteExpenseImages({
    required String callRequestId,
    required String imageType,
  }) async {
    try {
      // Get the main document using the new naming convention
      final mainDocId = '${callRequestId}_${imageType}';
      final mainDoc = await _firestore
          .collection('expense_images')
          .doc(mainDocId)
          .get();

      if (!mainDoc.exists) {
        return true; // Already deleted or doesn't exist
      }

      final mainData = mainDoc.data()!;
      final totalDocuments = mainData['totalDocuments'] as int? ?? 1;

      // Delete all documents for this image type
      for (int i = 0; i < totalDocuments; i++) {
        final docId = i == 0
            ? '${callRequestId}_${imageType}'
            : '${callRequestId}_${imageType}_$i';
        await _firestore.collection('expense_images').doc(docId).delete();
      }

      return true;
    } catch (e) {
      print('Error deleting expense images: $e');
      return false;
    }
  }

  // Get image statistics for a call request and specific image type
  static Future<Map<String, dynamic>> getImageStatistics({
    required String callRequestId,
    required String imageType,
  }) async {
    try {
      final mainDocId = '${callRequestId}_${imageType}';
      final mainDoc = await _firestore
          .collection('expense_images')
          .doc(mainDocId)
          .get();

      if (!mainDoc.exists) {
        return {
          'totalImages': 0,
          'totalDocuments': 0,
          'imageType': imageType,
          'estimatedSize': 0,
        };
      }

      final data = mainDoc.data()!;
      final totalImages = data['totalImages'] as int? ?? 0;
      final totalDocuments = data['totalDocuments'] as int? ?? 0;

      // Get all images to calculate estimated size
      final allImages = await getExpenseImages(
        callRequestId: callRequestId,
        imageType: imageType,
      );

      final estimatedSize = allImages.fold<int>(
        0,
        (sum, image) => sum + image.length,
      );

      return {
        'totalImages': totalImages,
        'totalDocuments': totalDocuments,
        'imageType': imageType,
        'estimatedSize': estimatedSize,
      };
    } catch (e) {
      print('Error getting image statistics: $e');
      return {
        'totalImages': 0,
        'totalDocuments': 0,
        'imageType': imageType,
        'estimatedSize': 0,
      };
    }
  }
}
