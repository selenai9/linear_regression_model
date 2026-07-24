import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'theme.dart';

/// Rwanda's real province -> district structure, used to filter the
/// district dropdown based on the selected province.
const Map<String, List<String>> provinceDistricts = {
  'Kigali': ['Gasabo', 'Kicukiro', 'Nyarugenge'],
  'East': [
    'Bugesera', 'Gatsibo', 'Kayonza', 'Kirehe',
    'Ngoma', 'Nyagatare', 'Rwamagana',
  ],
  'North': ['Burera', 'Gakenke', 'Gicumbi', 'Musanze', 'Rulindo'],
  'South': [
    'Gisagara', 'Huye', 'Kamonyi', 'Muhanga',
    'Nyamagabe', 'Nyanza', 'Nyaruguru', 'Ruhango',
  ],
  'West': [
    'Karongi', 'Ngororero', 'Nyabihu', 'Nyamasheke',
    'Rubavu', 'Rusizi', 'Rutsiro',
  ],
};

const List<String> cropCategories = [
  'Banana for beer', 'Bush bean', 'Cassava', 'Climbing bean', 'Cooking banana',
  'Dessert banana', 'Fodder crops', 'Fruits', 'Groundnut', 'Irish potato',
  'Maize', 'Other cereals', 'Other crops', 'Paddy rice', 'Pea', 'Sorghum',
  'Soybean', 'Sweet potato', 'Taro & Yams', 'Vegetables', 'Wheat',
];

const List<String> seasons = ['A', 'B', 'C'];

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  final _plotAreaController = TextEditingController();
  final _cropAreaController = TextEditingController();

  String? _selectedCrop;
  String? _selectedProvince;
  String? _selectedDistrict;
  String? _selectedSeason;

  bool _isLoading = false;
  PredictionResult? _result;

  @override
  void dispose() {
    _plotAreaController.dispose();
    _cropAreaController.dispose();
    super.dispose();
  }

  Future<void> _onPredictPressed() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCrop == null ||
        _selectedProvince == null ||
        _selectedDistrict == null ||
        _selectedSeason == null) {
      setState(() {
        _result = const PredictionResult.failure(
          'Please fill in every field before predicting.',
        );
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _result = null;
    });

    final result = await _apiService.predictYield(
      plotAreaHa: double.parse(_plotAreaController.text),
      cropAreaHa: double.parse(_cropAreaController.text),
      cropCategory: _selectedCrop!,
      province: _selectedProvince!,
      district: _selectedDistrict!,
      season: _selectedSeason!,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final availableDistricts =
        _selectedProvince != null ? provinceDistricts[_selectedProvince!]! : <String>[];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('TerraPredict')),
      body: Stack(
        children: [
          // Full-page background: your real farmland image, with a dark
          // gradient overlay layered on top so white text stays readable.
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background.withOpacity(0.55),
                    AppColors.background.withOpacity(0.88),
                    AppColors.background.withOpacity(0.96),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
              _HeroHeader(),
              const SizedBox(height: AppSpacing.lg),

              _SectionCard(
                title: 'Plot Details',
                icon: Icons.terrain_outlined,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _NumberField(
                          controller: _plotAreaController,
                          label: 'Plot Area (ha)',
                          min: 0.001,
                          max: 10,
                          icon: Icons.crop_free,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _NumberField(
                          controller: _cropAreaController,
                          label: 'Crop Area (ha)',
                          min: 0.001,
                          max: 10,
                          icon: Icons.agriculture_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _Dropdown(
                          label: 'Crop',
                          value: _selectedCrop,
                          items: cropCategories,
                          onChanged: (v) => setState(() => _selectedCrop = v),
                          icon: Icons.hub_outlined,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _Dropdown(
                          label: 'Season',
                          value: _selectedSeason,
                          items: seasons,
                          onChanged: (v) => setState(() => _selectedSeason = v),
                          icon: Icons.wb_sunny_outlined,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              _SectionCard(
                title: 'Location',
                icon: Icons.location_on_outlined,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _Dropdown(
                          label: 'Province',
                          value: _selectedProvince,
                          items: provinceDistricts.keys.toList(),
                          onChanged: (v) => setState(() {
                            _selectedProvince = v;
                            _selectedDistrict = null; // reset district when province changes
                          }),
                          icon: Icons.map_outlined,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _Dropdown(
                          label: 'District',
                          value: _selectedDistrict,
                          items: availableDistricts,
                          onChanged: _selectedProvince == null
                              ? null
                              : (v) => setState(() => _selectedDistrict = v),
                          icon: Icons.explore_outlined,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _onPredictPressed,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.background,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bolt, size: 20),
                            SizedBox(width: 8),
                            Text('Predict Yield'),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              if (_result != null) _ResultDisplay(result: _result!),

              const SizedBox(height: AppSpacing.xl),
              const Center(
                child: Text(
                  '— S.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const SizedBox(
                  width: 22,
                  height: 22,
                  child: CustomPaint(painter: _ContourMarkPainter()),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Text(
                'SMALLHOLDER YIELD FORECAST',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Estimate Crop Yield',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter your plot details to get a predicted yield based on regional data models.',
            style: TextStyle(color: Colors.white.withOpacity(0.75)),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  icon: Icons.straighten,
                  value: '\u226410 ha',
                  label: 'PLOT SCOPE',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatChip(
                  icon: Icons.dataset_outlined,
                  value: '62K+',
                  label: 'PLOTS TRAINED ON',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A small custom mark: three nested, irregular contour lines -- like
/// topographic elevation rings on a map. Ties directly to "Terra"Predict's
/// own name rather than a generic leaf/plant icon.
class _ContourMarkPainter extends CustomPainter {
  const _ContourMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Three nested rings, each slightly offset and irregular (not perfect
    // circles) to read as hand-drawn contour lines rather than a logo template.
    _drawContour(canvas, center, size.width * 0.46, 0.10, 0.75);
    _drawContour(canvas, center + const Offset(0.5, 1.2), size.width * 0.32, -0.14, 0.55);
    _drawContour(canvas, center + const Offset(1, 2), size.width * 0.17, 0.18, 0.35);
  }

  void _drawContour(Canvas canvas, Offset center, double radius, double wobble, double opacity) {
    final paint = Paint()
      ..color = AppColors.accent.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final path = Path();
    const steps = 24;
    for (int i = 0; i <= steps; i++) {
      final t = (i / steps) * 2 * math.pi;
      final wave = 1 + wobble * 0.12 * math.sin(t * 3);
      final r = radius * wave;
      final dx = center.dx + r * math.cos(t);
      final dy = center.dy + r * math.sin(t);
      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = Colors.white.withOpacity(0.06);
    const spacing = 18.0;
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.1, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Draws three overlapping rounded hill bumps along the bottom edge --
/// a clearly-readable rolling-hills silhouette (not a single wave curve),
/// evoking farmland without using any external image (avoids copyright
/// concerns and keeps the app fully self-contained).
class _HillsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _drawHill(canvas, size, centerXFraction: 0.15, radiusFraction: 0.55, heightFraction: 0.55, opacity: 0.35);
    _drawHill(canvas, size, centerXFraction: 0.55, radiusFraction: 0.70, heightFraction: 0.80, opacity: 0.55);
    _drawHill(canvas, size, centerXFraction: 0.92, radiusFraction: 0.50, heightFraction: 0.65, opacity: 0.75);
  }

  void _drawHill(
    Canvas canvas,
    Size size, {
    required double centerXFraction,
    required double radiusFraction,
    required double heightFraction,
    required double opacity,
  }) {
    final paint = Paint()..color = const Color(0xFF3E6350).withOpacity(opacity);
    final radius = size.width * radiusFraction * 0.5;
    final centerX = size.width * centerXFraction;
    final bumpTop = size.height * (1 - heightFraction);

    final path = Path()
      ..moveTo(centerX - radius, size.height)
      ..quadraticBezierTo(centerX - radius, bumpTop, centerX, bumpTop)
      ..quadraticBezierTo(centerX + radius, bumpTop, centerX + radius, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatChip({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.55),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final double min;
  final double max;
  final bool isInteger;
  final IconData? icon;

  const _NumberField({
    required this.controller,
    required this.label,
    required this.min,
    required this.max,
    this.isInteger = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: !isInteger),
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 20, color: AppColors.textSecondary) : null,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Required';
        }
        final parsed = double.tryParse(value);
        if (parsed == null) {
          return 'Enter a valid number';
        }
        if (parsed < min || parsed > max) {
          return 'Must be between $min and $max';
        }
        return null;
      },
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?>? onChanged;
  final IconData? icon;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 20, color: AppColors.textSecondary) : null,
      ),
      dropdownColor: AppColors.surfaceLight,
      style: const TextStyle(color: AppColors.textPrimary),
      isExpanded: true,
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Required' : null,
    );
  }
}

class _ResultDisplay extends StatelessWidget {
  final PredictionResult result;

  const _ResultDisplay({required this.result});

  @override
  Widget build(BuildContext context) {
    if (result.isSuccess) {
      final yieldValue = result.predictedYield!;
      // Normalize against a realistic upper bound for smallholder plots so the
      // gauge arc has a meaningful fill level (not just always near-empty or
      // always full). Clamped so extreme values don't overflow the arc.
      const maxExpectedYield = 20000.0;
      final progress = (yieldValue / maxExpectedYield).clamp(0.0, 1.0);

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          children: [
            const Text(
              'PREDICTED YIELD',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: 170,
              height: 170,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 170,
                    height: 170,
                    child: CircularProgressIndicator(
                      value: 1,
                      strokeWidth: 10,
                      strokeCap: StrokeCap.round,
                      color: AppColors.surfaceLight,
                    ),
                  ),
                  SizedBox(
                    width: 170,
                    height: 170,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 10,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        yieldValue.toStringAsFixed(0),
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'KG',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              result.errorMessage!,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}