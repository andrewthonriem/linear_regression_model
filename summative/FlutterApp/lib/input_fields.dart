// The 10 model inputs: one text field per variable the API expects.
import 'package:flutter/material.dart';

enum InputKind { integer, decimal, text }

class InputSpec {
  final String key; // name of the field in the API request
  final String label;
  final String helper; // allowed range, shown under the field
  final String hint; // example value (South Sudan, 2015)
  final InputKind kind;
  final IconData icon;

  const InputSpec(
    this.key,
    this.label,
    this.helper,
    this.hint,
    this.kind,
    this.icon,
  );
}

const List<InputSpec> inputs = [
  InputSpec(
    'year',
    'Year',
    'Whole number, 2000 to 2035',
    '2015',
    InputKind.integer,
    Icons.calendar_today,
  ),
  InputSpec(
    'access_to_electricity',
    'Access to electricity (%)',
    '0 to 100',
    '4.8',
    InputKind.decimal,
    Icons.bolt,
  ),
  InputSpec(
    'gdp_per_capita',
    'GDP per capita (US\$)',
    '50 to 250,000',
    '1071.8',
    InputKind.decimal,
    Icons.attach_money,
  ),
  InputSpec(
    'urban_population',
    'Urban population (%)',
    '0 to 100',
    '18.9',
    InputKind.decimal,
    Icons.location_city,
  ),
  InputSpec(
    'population_density',
    'Population density (people per km²)',
    '0.1 to 30,000',
    '17.7',
    InputKind.decimal,
    Icons.people,
  ),
  InputSpec(
    'life_expectancy',
    'Life expectancy (years)',
    '30 to 90',
    '55.6',
    InputKind.decimal,
    Icons.favorite,
  ),
  InputSpec(
    'birth_rate',
    'Birth rate (per 1,000 people)',
    '3 to 60',
    '36.3',
    InputKind.decimal,
    Icons.child_care,
  ),
  InputSpec(
    'education_expenditure',
    'Education spending (% of GDP)',
    '0 to 20',
    '1.47',
    InputKind.decimal,
    Icons.school,
  ),
  InputSpec(
    'government_effectiveness',
    'Government effectiveness score',
    '-2.5 (weak) to 2.5 (strong)',
    '-2.15',
    InputKind.decimal,
    Icons.account_balance,
  ),
  InputSpec(
    'region',
    'Region',
    'Name or code: SSA, EAP, ECA, LAC, MENA, NA, SA',
    'Sub-Saharan Africa',
    InputKind.text,
    Icons.public,
  ),
];

final Map<String, InputSpec> specByKey = {for (final s in inputs) s.key: s};

/// How the fields are grouped into cards on the page: (title, field keys).
const List<(String, List<String>)> sections = [
  ('Time & place', ['year', 'region']),
  (
    'Infrastructure',
    ['access_to_electricity', 'urban_population', 'population_density'],
  ),
  ('Economy & education', ['gdp_per_capita', 'education_expenditure']),
  (
    'People & governance',
    ['life_expectancy', 'birth_rate', 'government_effectiveness'],
  ),
];
