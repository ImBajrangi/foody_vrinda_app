# Implementation Plan - Optimized Image Rendering

The goal is to ensure that shop and menu images uploaded by users are displayed "perfectly" using high-quality rendering techniques, consistent aspect ratios, and smooth transitions.

## Proposed Changes

### [Visual Components]
#### [MODIFY] [cards.dart](file:///Users/mr.bajrangi/Visual%20Studio%20Code/Projects/Cloud-Kitchen/foody_vrinda_app/lib/widgets/cards.dart)
- Wrap shop and menu item images in `Hero` widgets for smooth transitions.
- Enhance `ShopCard` with a subtle gradient overlay on the image to improve text legibility if needed (though current design has text below).
- Add a "shimmer" loading effect for a more premium feel.

### [Shop Details]
#### [MODIFY] [menu_screen.dart](file:///Users/mr.bajrangi/Visual%20Studio%20Code/Projects/Cloud-Kitchen/foody_vrinda_app/lib/screens/menu/menu_screen.dart)
- Add a large Shop Banner at the top of the menu screen.
- Implement a `SliverAppBar` effect or a dedicated header image that uses the shop's `imageUrl`.
- Ensure the image has a `BoxFit.cover` behavior to handle various upload aspect ratios gracefully.

### [Theme & Styles]
#### [MODIFY] [theme.dart](file:///Users/mr.bajrangi/Visual%20Studio%20Code/Projects/Cloud-Kitchen/foody_vrinda_app/lib/config/theme.dart)
- Define universal image decoration constants (shadows, border radius).

## Verification Plan

### Manual Verification
- **Aspect Ratio Check**: Upload images of different aspect ratios (portrait, landscape, square) to Firebase and verify they are cropped correctly without stretching.
- **Transition Check**: Verify the `Hero` animation when tapping a shop card.
- **Loading States**: Check the shimmer/placeholder effect on a slow connection.
