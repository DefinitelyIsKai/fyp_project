import 'package:flutter/material.dart';

class FormValidationHelper {

  static bool validateAndScroll(GlobalKey<FormState> formKey, BuildContext context, {ScrollController? scrollController}) {
    final formState = formKey.currentState;
    if (formState == null) return false;
    
    // Validate the form
    final isValid = formState.validate();
    
    if (!isValid) {
      final formContext = formKey.currentContext ?? context;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToFirstErrorField(formContext, scrollController: scrollController);
        });
      });
    }
    
    return isValid;
  }
  
  static void _scrollToFirstErrorField(BuildContext context, {ScrollController? scrollController}) {
    BuildContext? errorContext;
    RenderObject? errorRenderObject;
    
    void visitElement(Element element) {
      if (errorContext != null) return; 
      if (element is StatefulElement) {
        final state = element.state;
        if (state is FormFieldState && state.hasError) {
          errorContext = element;
          final renderObject = element.findRenderObject();
          if (renderObject != null) {
            errorRenderObject = renderObject;
          }
          return;
        }
      }
      
      element.visitChildElements(visitElement);
    }
    
    final currentElement = context as Element?;
    if (currentElement != null) {
      Element? formElement;
      currentElement.visitAncestorElements((element) {
        if (element.widget is Form) {
          formElement = element;
          return false; 
        }
        return true; 
      });
      
      if (formElement != null) {
        visitElement(formElement!);
      } else {
        visitElement(currentElement);
      }
    }
    
    if (errorContext != null && errorRenderObject != null) {
      try {
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
      
      if (scrollController != null && scrollController.hasClients && errorRenderObject!.attached) {
        try {
          final RenderBox? renderBox = errorRenderObject as RenderBox?;
          if (renderBox != null) {
            final position = renderBox.localToGlobal(Offset.zero);
            final scrollPosition = scrollController.position;
            
            //offset
            final targetOffset = scrollPosition.pixels + position.dy - 100; 
            
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
    
    _fallbackScroll(context, scrollController: scrollController);
  }
  
  static void _fallbackScroll(BuildContext context, {ScrollController? scrollController}) {
    try {
      if (scrollController != null && scrollController.hasClients) {
        scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        debugPrint('Fallback: scrolled to top using provided controller');
        return;
      }
      
      final scrollable = Scrollable.maybeOf(context);
      if (scrollable == null) return;
      
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

