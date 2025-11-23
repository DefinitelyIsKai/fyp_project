# Project Refactoring Summary

## Overview
Reusable utilities and widgets have been extracted and organized into separate folders for better code organization and reusability.

## New Folder Structure

### `/lib/utils/`
Contains reusable utility functions:

#### `date_formatters.dart`
- `DateFormatters.formatDate()` - Format as 'dd/MM/yyyy'
- `DateFormatters.formatDateLong()` - Format as 'MMM dd, yyyy'
- `DateFormatters.formatDateTime()` - Format as 'MMM dd, yyyy • hh:mm a'
- `DateFormatters.formatDateTimeWithDash()` - Format as 'MMM dd, yyyy - HH:mm'
- `DateFormatters.formatDateTimeDetailed()` - Format as 'dd MMM yyyy, hh:mm a'
- `DateFormatters.formatDateTimeDetailed24()` - Format as 'dd MMM yyyy, HH:mm'
- `DateFormatters.formatDateShort()` - Format as 'MMM dd' (for charts)
- `DateFormatters.formatDateMedium()` - Format as 'dd MMM yyyy'
- `DateFormatters.formatTimeAgo()` - Format relative time (e.g., "2 hours ago")
- `DateFormatters.getDateRangeText()` - Get formatted date range text

#### `snackbar_utils.dart`
- `SnackbarUtils.showSnackBar()` - Show snackbar with optional error styling
- `SnackbarUtils.showSuccess()` - Show success snackbar
- `SnackbarUtils.showError()` - Show error snackbar
- `SnackbarUtils.showInfo()` - Show info snackbar

### `/lib/widgets/`
Contains reusable widget components:

#### `/widgets/common/`
- `detail_row.dart` - `DetailRow` widget for label-value pairs in detail pages
- `info_chip.dart` - `InfoChip` widget with icon and text
- `status_chip.dart` - `StatusChip` widget for displaying status with colors

#### `/widgets/cards/`
- `stat_card.dart` - `StatCard` widget for displaying statistics
- `quick_stat_card.dart` - `QuickStatCard` widget with trend indicator

#### `/widgets/dialogs/`
- `date_range_picker_dialog.dart` - `DateRangePickerDialog` widget for selecting date ranges

## Usage Examples

### Using Date Formatters
```dart
import 'package:fyp_project/utils/utils.dart';

// Instead of:
String _formatDate(DateTime date) {
  return DateFormat('dd/MM/yyyy').format(date);
}

// Use:
DateFormatters.formatDate(date);
DateFormatters.formatTimeAgo(date);
```

### Using Snackbar Utils
```dart
import 'package:fyp_project/utils/utils.dart';

// Instead of:
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(message),
    backgroundColor: Colors.red,
  ),
);

// Use:
SnackbarUtils.showError(context, message);
SnackbarUtils.showSuccess(context, message);
```

### Using Reusable Widgets
```dart
import 'package:fyp_project/widgets/widgets.dart';

// Use DetailRow
DetailRow(
  label: 'Status',
  value: 'Active',
  valueColor: Colors.green,
)

// Use StatusChip
StatusChip(status: 'pending')

// Use InfoChip
InfoChip(
  text: 'Location',
  icon: Icons.location_on,
  color: Colors.blue,
)

// Use StatCard
StatCard(
  title: 'Total Users',
  value: '1,234',
  color: Colors.blue,
  icon: Icons.people,
)

// Use QuickStatCard
QuickStatCard(
  title: 'Active Users',
  value: '567',
  subtitle: 'Online now',
  color: Colors.green,
  icon: Icons.people_alt,
  trend: 5.2,
)

// Use DateRangePickerDialog
final result = await DateRangePickerDialog.show(
  context,
  startDate: _startDate,
  endDate: _endDate,
);
```

## Next Steps

To complete the refactoring, you should:

1. **Update imports** in existing files to use the new utilities and widgets
2. **Remove duplicate code** - Delete local `_formatDate`, `_showSnackBar`, `_DetailRow`, etc. implementations
3. **Replace inline widgets** with the reusable components from `/lib/widgets/`

## Files That Need Updates

The following files likely contain code that can be replaced with the new utilities/widgets:

- `lib/pages/admin/analytics/analytics_page.dart` - Date formatting, snackbars, cards, dialogs
- `lib/pages/admin/user_management/user_detail_page.dart` - Date formatting, snackbars, DetailRow, InfoChip
- `lib/pages/admin/user_management/view_users_page.dart` - Date formatting, snackbars
- `lib/pages/admin/message_oversight/*.dart` - Date formatting, snackbars, DetailRow
- `lib/pages/admin/post_moderation/*.dart` - Date formatting, snackbars, StatusChip, InfoChip
- `lib/pages/admin/dashboard/dashboard_page.dart` - StatCard
- And other pages with similar patterns

## Benefits

1. **Code Reusability** - Write once, use everywhere
2. **Consistency** - Same formatting and styling across the app
3. **Maintainability** - Update in one place, affects all usages
4. **Cleaner Code** - Less duplication, more readable
5. **Easier Testing** - Test utilities and widgets independently

