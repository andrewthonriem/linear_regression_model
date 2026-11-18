// The single page of the app: input fields, Predict button, result area.
import 'package:flutter/material.dart';

import 'api_service.dart';
import 'input_fields.dart';
import 'main.dart';

class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  final Map<String, TextEditingController> _controllers = {
    for (final spec in inputs) spec.key: TextEditingController(),
  };

  bool _loading = false;
  PredictionResult? _result;
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _predict() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _result = null;
    });

    try {
      final body = buildRequestBody({
        for (final e in _controllers.entries) e.key: e.value.text,
      });
      setState(() => _loading = true);
      final result = await fetchPrediction(body);
      if (mounted) setState(() => _result = result);
    } on PredictionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Fills every field with South Sudan's 2015 values.
  void _fillExample() {
    for (final spec in inputs) {
      _controllers[spec.key]!.text = spec.hint;
    }
    setState(() {
      _error = null;
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Header(),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Country indicators',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.forest,
                      ),
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.forest,
                      side: const BorderSide(color: AppColors.amber),
                    ),
                    onPressed: _loading ? null : _fillExample,
                    child: const Text('South Sudan 2015'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              for (final (title, keys) in sections)
                _SectionCard(
                  title: title,
                  keys: keys,
                  controllers: _controllers,
                ),
              const SizedBox(height: 4),
              _PredictButton(loading: _loading, onPressed: _predict),
              const SizedBox(height: 16),
              _ResultArea(loading: _loading, result: _result, error: _error),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'Data: World Bank WDI  •  Model: Random forest',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.forest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.wifi, color: AppColors.amber),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Internet Access Predictor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Predict the share of a country's population using the internet, "
            'and whether learning and document services should be delivered '
            'online or offline.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// A white card holding one group of labelled text fields.
class _SectionCard extends StatelessWidget {
  final String title;
  final List<String> keys;
  final Map<String, TextEditingController> controllers;

  const _SectionCard({
    required this.title,
    required this.keys,
    required this.controllers,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 14),
          for (final key in keys) _buildField(specByKey[key]!),
        ],
      ),
    );
  }

  Widget _buildField(InputSpec spec) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        key: ValueKey('field_${spec.key}'),
        controller: controllers[spec.key],
        keyboardType: spec.kind == InputKind.text
            ? TextInputType.text
            : TextInputType.numberWithOptions(
                decimal: spec.kind == InputKind.decimal,
                signed: true,
              ),
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: spec.label,
          helperText: spec.helper,
          hintText: 'e.g. ${spec.hint}',
          prefixIcon: Icon(spec.icon, color: AppColors.emerald, size: 20),
        ),
      ),
    );
  }
}

class _PredictButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;

  const _PredictButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.emerald,
          disabledBackgroundColor: AppColors.emerald.withValues(alpha: 0.6),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.insights),
        label: const Text(
          'Predict',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Shows the prediction, or an error message, in the same place.
class _ResultArea extends StatelessWidget {
  final bool loading;
  final PredictionResult? result;
  final String? error;

  const _ResultArea({required this.loading, this.result, this.error});

  @override
  Widget build(BuildContext context) {
    final isError = !loading && error != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isError ? AppColors.errorBackground : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isError ? AppColors.crimson : AppColors.border,
        ),
      ),
      child: _content(),
    );
  }

  Widget _content() {
    if (loading) {
      return const Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Predicting... the first request can take up to a minute.',
            ),
          ),
        ],
      );
    }
    if (error != null) {
      return Text(
        error!,
        key: const ValueKey('error_text'),
        style: const TextStyle(color: AppColors.errorText, height: 1.4),
      );
    }
    if (result == null) {
      return const Text(
        'The prediction will appear here.',
        style: TextStyle(color: AppColors.textMuted),
      );
    }

    final p = result!.percent;
    final color = AppColors.forLevel(p);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Predicted internet users',
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 4),
        Text(
          '${p.toStringAsFixed(1)}%',
          key: const ValueKey('prediction_text'),
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (p / 100).clamp(0, 1),
            minHeight: 8,
            color: color,
            backgroundColor: AppColors.border,
          ),
        ),
        if (result!.interpretation != null) ...[
          const SizedBox(height: 14),
          Text(
            result!.interpretation!,
            style: const TextStyle(color: AppColors.forest, height: 1.4),
          ),
        ],
      ],
    );
  }
}
