import '../models/state_info.dart';

/// Bundled static state data: the 50 states plus D.C., with their capitals.
///
/// Capitals are stable facts and answer the "capital of your state" civics
/// question offline. The person-name fields (governor, senators,
/// representative) change over time, so they are left for the user to enter in
/// "My State Info" or to refresh from a public API (see CongressApiService).
const List<StateInfo> kStates = [
  StateInfo(code: 'AL', name: 'Alabama', capital: 'Montgomery'),
  StateInfo(code: 'AK', name: 'Alaska', capital: 'Juneau'),
  StateInfo(code: 'AZ', name: 'Arizona', capital: 'Phoenix'),
  StateInfo(code: 'AR', name: 'Arkansas', capital: 'Little Rock'),
  StateInfo(code: 'CA', name: 'California', capital: 'Sacramento'),
  StateInfo(code: 'CO', name: 'Colorado', capital: 'Denver'),
  StateInfo(code: 'CT', name: 'Connecticut', capital: 'Hartford'),
  StateInfo(code: 'DE', name: 'Delaware', capital: 'Dover'),
  StateInfo(code: 'FL', name: 'Florida', capital: 'Tallahassee'),
  StateInfo(code: 'GA', name: 'Georgia', capital: 'Atlanta'),
  StateInfo(code: 'HI', name: 'Hawaii', capital: 'Honolulu'),
  StateInfo(code: 'ID', name: 'Idaho', capital: 'Boise'),
  StateInfo(code: 'IL', name: 'Illinois', capital: 'Springfield'),
  StateInfo(code: 'IN', name: 'Indiana', capital: 'Indianapolis'),
  StateInfo(code: 'IA', name: 'Iowa', capital: 'Des Moines'),
  StateInfo(code: 'KS', name: 'Kansas', capital: 'Topeka'),
  StateInfo(code: 'KY', name: 'Kentucky', capital: 'Frankfort'),
  StateInfo(code: 'LA', name: 'Louisiana', capital: 'Baton Rouge'),
  StateInfo(code: 'ME', name: 'Maine', capital: 'Augusta'),
  StateInfo(code: 'MD', name: 'Maryland', capital: 'Annapolis'),
  StateInfo(code: 'MA', name: 'Massachusetts', capital: 'Boston'),
  StateInfo(code: 'MI', name: 'Michigan', capital: 'Lansing'),
  StateInfo(code: 'MN', name: 'Minnesota', capital: 'Saint Paul'),
  StateInfo(code: 'MS', name: 'Mississippi', capital: 'Jackson'),
  StateInfo(code: 'MO', name: 'Missouri', capital: 'Jefferson City'),
  StateInfo(code: 'MT', name: 'Montana', capital: 'Helena'),
  StateInfo(code: 'NE', name: 'Nebraska', capital: 'Lincoln'),
  StateInfo(code: 'NV', name: 'Nevada', capital: 'Carson City'),
  StateInfo(code: 'NH', name: 'New Hampshire', capital: 'Concord'),
  StateInfo(code: 'NJ', name: 'New Jersey', capital: 'Trenton'),
  StateInfo(code: 'NM', name: 'New Mexico', capital: 'Santa Fe'),
  StateInfo(code: 'NY', name: 'New York', capital: 'Albany'),
  StateInfo(code: 'NC', name: 'North Carolina', capital: 'Raleigh'),
  StateInfo(code: 'ND', name: 'North Dakota', capital: 'Bismarck'),
  StateInfo(code: 'OH', name: 'Ohio', capital: 'Columbus'),
  StateInfo(code: 'OK', name: 'Oklahoma', capital: 'Oklahoma City'),
  StateInfo(code: 'OR', name: 'Oregon', capital: 'Salem'),
  StateInfo(code: 'PA', name: 'Pennsylvania', capital: 'Harrisburg'),
  StateInfo(code: 'RI', name: 'Rhode Island', capital: 'Providence'),
  StateInfo(code: 'SC', name: 'South Carolina', capital: 'Columbia'),
  StateInfo(code: 'SD', name: 'South Dakota', capital: 'Pierre'),
  StateInfo(code: 'TN', name: 'Tennessee', capital: 'Nashville'),
  StateInfo(code: 'TX', name: 'Texas', capital: 'Austin'),
  StateInfo(code: 'UT', name: 'Utah', capital: 'Salt Lake City'),
  StateInfo(code: 'VT', name: 'Vermont', capital: 'Montpelier'),
  StateInfo(code: 'VA', name: 'Virginia', capital: 'Richmond'),
  StateInfo(code: 'WA', name: 'Washington', capital: 'Olympia'),
  StateInfo(code: 'WV', name: 'West Virginia', capital: 'Charleston'),
  StateInfo(code: 'WI', name: 'Wisconsin', capital: 'Madison'),
  StateInfo(code: 'WY', name: 'Wyoming', capital: 'Cheyenne'),
  // The District of Columbia is not a state; USCIS has specific guidance for
  // its residents on the state-dependent questions.
  StateInfo(code: 'DC', name: 'District of Columbia', capital: 'N/A'),
];

/// Look up bundled state data by two-letter code.
StateInfo? stateByCode(String code) {
  final upper = code.toUpperCase();
  for (final s in kStates) {
    if (s.code == upper) return s;
  }
  return null;
}
