import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_decorations.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/eco/eco_local_store.dart';
import '../../../providers/auth_provider.dart';
import '../../components/eco/eco_animations.dart';
import '../../components/primary_button.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _editing = false;
  bool _showAddCard = false;
  bool _loadingLocal = true;
  double _wallet = 250;
  String _home = '';
  String _work = '';
  List<EcoPaymentCard> _cards = [];
  String _topUpAmount = '100';
  String _cardBrand = 'visa';
  final _cardLast4 = TextEditingController();
  final _cardExpiry = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _homeCtrl = TextEditingController();
  final _workCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLocal();
  }

  Future<void> _loadLocal() async {
    final wallet = await EcoLocalStore.walletBalance();
    final home = await EcoLocalStore.homeAddress();
    final work = await EcoLocalStore.workAddress();
    final cards = await EcoLocalStore.paymentCards();
    if (mounted) {
      setState(() {
        _wallet = wallet;
        _home = home;
        _work = work;
        _cards = cards;
        _homeCtrl.text = home;
        _workCtrl.text = work;
        _loadingLocal = false;
      });
    }
  }

  @override
  void dispose() {
    _cardLast4.dispose();
    _cardExpiry.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _homeCtrl.dispose();
    _workCtrl.dispose();
    super.dispose();
  }

  Future<void> _topUp() async {
    final amt = double.tryParse(_topUpAmount);
    if (amt == null || amt <= 0) return;
    final next = _wallet + amt;
    await EcoLocalStore.setWalletBalance(next);
    setState(() => _wallet = next);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Topped up ₱${amt.toStringAsFixed(0)} to EcoPay')),
      );
    }
  }

  Future<void> _addCard() async {
    if (_cardLast4.text.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter exactly 4 digits for last 4')),
      );
      return;
    }
    final card = EcoPaymentCard(
      id: 'card-${DateTime.now().millisecondsSinceEpoch}',
      brand: _cardBrand,
      last4: _cardLast4.text,
      expiry: _cardExpiry.text.isEmpty ? '12/29' : _cardExpiry.text,
    );
    final next = [..._cards, card];
    await EcoLocalStore.savePaymentCards(next);
    setState(() {
      _cards = next;
      _showAddCard = false;
      _cardLast4.clear();
      _cardExpiry.clear();
    });
  }

  Future<void> _deleteCard(String id) async {
    final next = _cards.where((c) => c.id != id).toList();
    await EcoLocalStore.savePaymentCards(next);
    setState(() => _cards = next);
  }

  Future<void> _saveProfile() async {
    await EcoLocalStore.setHomeAddress(_homeCtrl.text.trim());
    await EcoLocalStore.setWorkAddress(_workCtrl.text.trim());
    setState(() {
      _home = _homeCtrl.text.trim();
      _work = _workCtrl.text.trim();
      _editing = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved bookmarks locally')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final authEmail = ref.watch(authRepositoryProvider).currentUser?.email;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('MY ECORIDE ACCOUNT', style: AppTextStyles.label),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        actions: [
          TextButton(
            onPressed: _editing ? _saveProfile : () => setState(() => _editing = true),
            child: Text(
              _editing ? 'Save' : 'Edit',
              style: AppTextStyles.body.copyWith(
                color: AppColors.ecoGreenLight,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.ecoGreen)),
        error: (_, __) => _buildBody(name: AppStrings.placeholderName, email: authEmail ?? ''),
        data: (user) => _buildBody(
          name: user?.fullName.trim().isNotEmpty == true
              ? user!.fullName
              : AppStrings.placeholderName,
          email: user?.email.trim().isNotEmpty == true
              ? user!.email
              : (authEmail ?? AppStrings.placeholderEmail),
          phone: user?.phone ?? AppStrings.placeholderPhone,
        ),
      ),
    );
  }

  Widget _buildBody({required String name, required String email, String? phone}) {
    if (_nameCtrl.text.isEmpty) {
      _nameCtrl.text = name;
      _emailCtrl.text = email;
      _phoneCtrl.text = phone ?? '';
    }

    if (_loadingLocal) {
      return const Center(child: CircularProgressIndicator(color: AppColors.ecoGreen));
    }

    return EcoFadeIn(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppDecorations.ecoCard,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.ecoGreen.withValues(alpha: 0.2),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: AppTextStyles.displayMetric,
                  ),
                ),
                const SizedBox(height: 12),
                if (_editing) ...[
                  _editField(_nameCtrl, 'Name'),
                  const SizedBox(height: 8),
                  _editField(_emailCtrl, 'Email'),
                  const SizedBox(height: 8),
                  _editField(_phoneCtrl, 'Phone'),
                ] else ...[
                  Text(name, style: AppTextStyles.headingLg, textAlign: TextAlign.center),
                  Text(email, style: AppTextStyles.bodySecondary.copyWith(fontSize: 11)),
                  if (phone != null)
                    Text(phone, style: AppTextStyles.bodySecondary.copyWith(fontSize: 11)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.forestMedium,
                  AppColors.forestLight.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.forestLight.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ECOPAY CASHLESS WALLET',
                    style: AppTextStyles.label.copyWith(fontSize: 9)),
                Text(
                  '₱${_wallet.toStringAsFixed(2)}',
                  style: AppTextStyles.displayMetric.copyWith(color: AppColors.ecoCream),
                ),
                const SizedBox(height: 12),
                Text('QUICK BALANCE TOP-UP', style: AppTextStyles.label.copyWith(fontSize: 9)),
                const SizedBox(height: 8),
                Row(
                  children: ['50', '100', '250', '500']
                      .map(
                        (amt) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Material(
                              color: _topUpAmount == amt
                                  ? AppColors.ecoGreen
                                  : AppColors.forestMedium,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => setState(() => _topUpAmount = amt),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    '₱$amt',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.label.copyWith(
                                      color: AppColors.ecoCream,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _topUp,
                    child: Text(
                      'Top up ₱$_topUpAmount',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.ecoGreenLight,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle('SAVED BOOKMARKS'),
          _bookmarkRow(Icons.home_outlined, 'Home landmark', _home, _homeCtrl),
          const SizedBox(height: 10),
          _bookmarkRow(Icons.work_outline, 'Work landmark', _work, _workCtrl),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _sectionTitle('SAVED CARDS')),
              TextButton(
                onPressed: () => setState(() => _showAddCard = !_showAddCard),
                child: Text(
                  '+ Add new',
                  style: AppTextStyles.label.copyWith(color: AppColors.ecoGreenLight),
                ),
              ),
            ],
          ),
          if (_showAddCard) ...[
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: AppDecorations.ecoCard,
              child: Column(
                children: [
                  Row(
                    children: ['visa', 'mastercard', 'amex']
                        .map(
                          (b) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: OutlinedButton(
                                onPressed: () => setState(() => _cardBrand = b),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _cardBrand == b
                                      ? AppColors.ecoGreenLight
                                      : AppColors.textSecondary,
                                  side: BorderSide(
                                    color: _cardBrand == b
                                        ? AppColors.ecoGreen
                                        : AppColors.forestLight,
                                  ),
                                ),
                                child: Text(b.toUpperCase(), style: const TextStyle(fontSize: 9)),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _cardLast4,
                          maxLength: 4,
                          keyboardType: TextInputType.number,
                          style: AppTextStyles.body,
                          decoration: const InputDecoration(
                            counterText: '',
                            hintText: 'Last 4',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _cardExpiry,
                          style: AppTextStyles.body,
                          decoration: const InputDecoration(hintText: 'MM/YY'),
                        ),
                      ),
                    ],
                  ),
                  PrimaryButton(label: 'Integrate card', onPressed: _addCard),
                ],
              ),
            ),
          ],
          ..._cards.map(
            (c) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: AppDecorations.ecoCard,
              child: Row(
                children: [
                  const Icon(Icons.credit_card, color: AppColors.ecoGreenLight, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c.brand.toUpperCase()} •••• ${c.last4}',
                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text('Expires ${c.expiry}',
                            style: AppTextStyles.bodySecondary.copyWith(fontSize: 10)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _deleteCard(c.id),
                    icon: const Icon(Icons.delete_outline, color: AppColors.rose, size: 20),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: AppStrings.logOut,
            useAccent: false,
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: AppTextStyles.label.copyWith(fontSize: 10)),
    );
  }

  Widget _editField(TextEditingController c, String hint) {
    return TextField(
      controller: c,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.forestMedium,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _bookmarkRow(
    IconData icon,
    String title,
    String value,
    TextEditingController ctrl,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.ecoCard,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.ecoGreen, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                _editing
                    ? TextField(
                        controller: ctrl,
                        style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                        decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                      )
                    : Text(value, style: AppTextStyles.bodySecondary.copyWith(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
