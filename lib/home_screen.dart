import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pay_flow/widgets/notifications_page.dart';
import 'package:pay_flow/widgets/work_process_page.dart';

import 'login_page.dart';
import 'invoice_form_page.dart';
import 'widgets/dashboard_page.dart';
import 'call_dashboard_page.dart';
import 'call_manager_dashboard_page.dart';
import 'accounts_calls_page.dart';
import 'debt_collection_calls_page.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  final String userType;
  const HomeScreen({super.key, required this.username, required this.userType});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex =
      0; // 0 = Dashboard, 1 = Work Process, 2 = Notifications, 3 = Calls

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 150,
        leading: Row(
          children: [
            // Menu icon to open the drawer
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Menu',
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            // Logo that navigates to Dashboard
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: InkWell(
                onTap: () {
                  setState(() => _selectedIndex = 0);
                },
                borderRadius: BorderRadius.circular(8),
                child: Tooltip(
                  message: 'Go to Dashboard',
                  child: Image.asset(
                    'assets/aams.jpg',
                    fit: BoxFit.contain,
                    height: 80,
                    width: 80,
                  ),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          _selectedIndex == 0
              ? 'Dashboard'
              : _selectedIndex == 1
              ? 'Work Process'
              : _selectedIndex == 2
              ? 'Notifications'
              : 'Calls',
        ),
        actions: [
          // Role-aware Calls badge/icon
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('call_requests')
                .snapshots(),
            builder: (context, snapshot) {
              int callBadge = 0;
              final docs = snapshot.data?.docs ?? [];
              final today = DateTime.now();
              final todayStart = DateTime(today.year, today.month, today.day);
              final todayEnd = todayStart.add(const Duration(days: 1));

              for (final doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status']?.toString() ?? '';

                if (widget.userType == 'debtCollection') {
                  // completed + poPending where followUp due today OR no followUps
                  if (status == 'completed' || status == 'poPending') {
                    final followUps =
                        (data['followUps'] as List<dynamic>?) ?? [];
                    if (followUps.isEmpty) {
                      callBadge++;
                    } else {
                      // check if any followUp due date is today
                      bool anyToday = false;
                      for (final fu in followUps) {
                        final due = fu['dueDate'];
                        if (due is Timestamp) {
                          final d = due.toDate();
                          if (d.isAfter(
                                todayStart.subtract(
                                  const Duration(microseconds: 1),
                                ),
                              ) &&
                              d.isBefore(todayEnd)) {
                            anyToday = true;
                            break;
                          }
                        } else if (due is String) {
                          final parsed = DateTime.tryParse(due);
                          if (parsed != null &&
                              parsed.isAfter(
                                todayStart.subtract(
                                  const Duration(microseconds: 1),
                                ),
                              ) &&
                              parsed.isBefore(todayEnd)) {
                            anyToday = true;
                            break;
                          }
                        }
                      }
                      if (anyToday) callBadge++;
                    }
                  }
                } else if (widget.userType == 'accounts') {
                  // pendingInvoice + pendingCredit
                  if (status == 'pendingInvoice' || status == 'pendingCredit')
                    callBadge++;
                } else if (widget.userType == 'callManager') {
                  // show pending approval
                  if (status == 'pendingApproval') callBadge++;
                } else if (widget.userType == 'call') {
                  // replace notification icon: calls icon with pendingReport due today
                  if (status == 'pendingReport') {
                    final dueRaw = data['pendingReportDueDate'];
                    if (dueRaw is Timestamp) {
                      final due = dueRaw.toDate();
                      if (due.isAfter(
                            todayStart.subtract(
                              const Duration(microseconds: 1),
                            ),
                          ) &&
                          due.isBefore(todayEnd))
                        callBadge++;
                    } else if (dueRaw is String) {
                      final parsed = DateTime.tryParse(dueRaw);
                      if (parsed != null &&
                          parsed.isAfter(
                            todayStart.subtract(
                              const Duration(microseconds: 1),
                            ),
                          ) &&
                          parsed.isBefore(todayEnd))
                        callBadge++;
                    }
                  }
                } else {
                  // default: nothing
                }
              }

              Widget icon = Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.call_outlined),
                  if (callBadge > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          callBadge > 99 ? '99+' : '$callBadge',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );

              return IconButton(
                tooltip: 'Calls',
                onPressed: () {
                  setState(() => _selectedIndex = 3);
                },
                icon: icon,
              );
            },
          ),
          // Notification bell icon with badge for accounts and debtCollection
          if (widget.userType == 'accounts' ||
              widget.userType == 'debtCollection' ||
              widget.userType == 'admin')
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('invoices')
                  .snapshots(),
              builder: (context, snapshot) {
                int notificationBadge = 0;
                final docs = snapshot.data?.docs ?? [];
                final today = DateTime.now();
                final todayStart = DateTime(today.year, today.month, today.day);
                final todayEnd = todayStart.add(const Duration(days: 1));

                // Count invoices in pending state with due date today
                for (final doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status']?.toString() ?? 'pending';

                  if (status == 'pending') {
                    final dueDate = data['dueDate'];
                    if (dueDate is Timestamp) {
                      final dueDateObject = dueDate.toDate();
                      if (dueDateObject.isAfter(
                            todayStart.subtract(
                              const Duration(microseconds: 1),
                            ),
                          ) &&
                          dueDateObject.isBefore(todayEnd)) {
                        notificationBadge++;
                      }
                    }
                  }
                }

                Widget icon = Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_outlined),
                    if (notificationBadge > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            notificationBadge > 99
                                ? '99+'
                                : '$notificationBadge',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );

                return IconButton(
                  tooltip: 'Notifications',
                  onPressed: () {
                    setState(() => _selectedIndex = 2);
                  },
                  icon: icon,
                );
              },
            ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.account_balance_wallet,
                    size: 40,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pay Flow',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'User: ${widget.username}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              selected: _selectedIndex == 0,
              onTap: () {
                setState(() => _selectedIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.work_outline),
              title: const Text('Work Process'),
              selected: _selectedIndex == 1,
              onTap: () {
                setState(() => _selectedIndex = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notifications'),
              selected: _selectedIndex == 2,
              onTap: () {
                setState(() => _selectedIndex = 2);
                Navigator.pop(context);
              },
            ),
            if (widget.userType == 'accounts' ||
                widget.userType == 'debtCollection')
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('call_requests')
                    .snapshots(),
                builder: (context, snapshot) {
                  int callsCount = 0;
                  final docs = snapshot.data?.docs ?? [];
                  final today = DateTime.now();
                  final todayStart = DateTime(
                    today.year,
                    today.month,
                    today.day,
                  );
                  final todayEnd = todayStart.add(const Duration(days: 1));

                  for (final doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status']?.toString() ?? '';

                    if (widget.userType == 'debtCollection') {
                      if (status == 'completed' || status == 'poPending') {
                        final followUps =
                            (data['followUps'] as List<dynamic>?) ?? [];
                        if (followUps.isEmpty) {
                          callsCount++;
                        } else {
                          bool anyToday = false;
                          for (final fu in followUps) {
                            final due = fu['dueDate'];
                            if (due is Timestamp) {
                              final d = due.toDate();
                              if (d.isAfter(
                                    todayStart.subtract(
                                      const Duration(microseconds: 1),
                                    ),
                                  ) &&
                                  d.isBefore(todayEnd)) {
                                anyToday = true;
                                break;
                              }
                            } else if (due is String) {
                              final parsed = DateTime.tryParse(due);
                              if (parsed != null &&
                                  parsed.isAfter(
                                    todayStart.subtract(
                                      const Duration(microseconds: 1),
                                    ),
                                  ) &&
                                  parsed.isBefore(todayEnd)) {
                                anyToday = true;
                                break;
                              }
                            }
                          }
                          if (anyToday) callsCount++;
                        }
                      }
                    } else if (widget.userType == 'accounts') {
                      if (status == 'pendingInvoice' ||
                          status == 'pendingCredit')
                        callsCount++;
                    }
                  }

                  return ListTile(
                    leading: const Icon(Icons.phone),
                    title: const Text('Calls'),
                    selected: _selectedIndex == 3,
                    onTap: () {
                      setState(() => _selectedIndex = 3);
                      Navigator.pop(context);
                    },
                    trailing: callsCount > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            child: Text(
                              callsCount > 99 ? '99+' : '$callsCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : null,
                  );
                },
              ),
          ],
        ),
      ),
      body: widget.userType == 'call'
          ? CallDashboardPage(username: widget.username)
          : widget.userType == 'callManager'
          ? CallManagerDashboardPage(username: widget.username)
          : _selectedIndex == 0
          ? DashboardPage(username: widget.username, userType: widget.userType)
          : _selectedIndex == 1
          ? WorkProcessPage(
              username: widget.username,
              userType: widget.userType,
            )
          : _selectedIndex == 2
          ? NotificationsPage(
              username: widget.username,
              userType: widget.userType,
            )
          : widget.userType == 'debtCollection'
          ? DebtCollectionCallsPage(username: widget.username)
          : AccountsCallsPage(username: widget.username),
      floatingActionButton:
          (_selectedIndex == 1 && widget.userType == 'accounts')
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => InvoiceFormPage(
                    username: widget.username,
                    userType: widget.userType,
                  ),
                ),
              ),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Add invoice'),
            )
          : null,
    );
  }
}
