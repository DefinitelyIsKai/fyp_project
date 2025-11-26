import 'package:flutter/material.dart';

class FormValidationHelper {

  static bool validateAndScroll(GlobalKey<FormState> formKey, BuildContext context, {ScrollController? scrollController}) {
    final formState = formKey.currentState;
    if (formState == null) return false;
    
    // Validate the form
    final isValid = formState.validate();
    
    if (!isValid) {
      // Get the form's context from the GlobalKey
      final formContext = formKey.currentContext ?? context;
      
      // Wait for errors to render, then scroll
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Wait one more frame to ensure error decorations are rendered
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToFirstErrorField(formContext, scrollController: scrollController);
        });
      });
    }
    
    return isValid;
  }
  
  static void _scrollToFirstErrorField(BuildContext context, {ScrollController? scrollController}) {
    // Find the first FormFieldState with an error by traversing the element tree
    BuildContext? errorContext;
    RenderObject? errorRenderObject;
    
    void visitElement(Element element) {
      if (errorContext != null) return; // Already found
      
      // Check if this element has a FormFieldState
      if (element is StatefulElement) {
        final state = element.state;
        if (state is FormFieldState && state.hasError) {
          errorContext = element;
          // Get the render object for scrolling
          final renderObject = element.findRenderObject();
          if (renderObject != null) {
            errorRenderObject = renderObject;
          }
          return;
        }
      }
      
      // Visit children recursively
      element.visitChildElements(visitElement);
    }
    
    // Start from the current context and traverse down
    final currentElement = context as Element?;
    if (currentElement != null) {
      // First, try to find the Form widget
      Element? formElement;
      
      // Find Form widget by traversing up
      currentElement.visitAncestorElements((element) {
        if (element.widget is Form) {
          formElement = element;
          return false; // Stop visiting
        }
        return true; // Continue visiting
      });
      
      // If we found the form, start from there
      if (formElement != null) {
        visitElement(formElement!);
      } else {
        // Otherwise, traverse from current element
        visitElement(currentElement);
      }
    }
    
    // If we found an error field, scroll to it
    if (errorContext != null && errorRenderObject != null) {
      try {
        // Try using Scrollable.ensureVisible first
        if (errorContext!.mounted) {
          Scrollable.ensureVisible(
            errorContext!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: 0.1,
          );
          debugPrint('Scrolled to error field successfully using ensureVisible');
          return;
        }
      } catch (e) {
        debugPrint('Error using ensureVisible: $e, trying scrollController');
      }
      
      // Fallback: use ScrollController if provided
      if (scrollController != null && scrollController.hasClients && errorRenderObject!.attached) {
        try {
          // Calculate the position of the error field
          final RenderBox? renderBox = errorRenderObject as RenderBox?;
          if (renderBox != null) {
            final position = renderBox.localToGlobal(Offset.zero);
            final scrollPosition = scrollController.position;
            
            // Calculate the scroll offset needed
            final targetOffset = scrollPosition.pixels + position.dy - 100; // 100px from top
            
            scrollController.animateTo(
              targetOffset.clamp(0.0, scrollPosition.maxScrollExtent),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
            debugPrint('Scrolled to error field successfully using scrollController');
            return;
          }
        } catch (e) {
          debugPrint('Error using scrollController: $e');
        }
      }
    } else {
      debugPrint('No error field found');
    }
    
    // Fallback: scroll to top of form if we couldn't find or scroll to error field
    _fallbackScroll(context, scrollController: scrollController);
  }
  
  static void _fallbackScroll(BuildContext context, {ScrollController? scrollController}) {
    // Alternative approach: scroll to the top of the scrollable area
    try {
      // Use provided scrollController if available
      if (scrollController != null && scrollController.hasClients) {
        scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        debugPrint('Fallback: scrolled to top using provided controller');
        return;
      }
      
      // Find the nearest Scrollable ancestor
      final scrollable = Scrollable.maybeOf(context);
      if (scrollable == null) return;
      
      // Try to scroll to the top of the form to show errors
      final controller = scrollable.widget.controller;
      if (controller != null && controller.hasClients) {
        controller.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        debugPrint('Fallback: scrolled to top using Scrollable controller');
      }
    } catch (e) {
      debugPrint('Fallback scroll failed: $e');
    }
  }
}

