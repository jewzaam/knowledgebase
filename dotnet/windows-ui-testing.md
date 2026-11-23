# Windows UI Testing with FlaUI and xUnit

Observed on a Windows 11 laptop.

- FlaUI.UIA3 5.0.0 runs on `net10.0-windows`.
- xUnit v3 4.0.3 lacks the concrete `Parallelization` attribute its docs
  describe. This assembly attribute serializes all tests in an assembly instead:

```csharp
[assembly: CollectionBehavior(CollectionBehavior.CollectionPerAssembly)]
```

- In WinForms, `AccessibleName` overrides the visible text as the UIA `Name`.
