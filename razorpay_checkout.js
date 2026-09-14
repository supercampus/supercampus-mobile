(function () {
  window.superCampusOpenRazorpay = function (options, onSuccess, onFailure, onDismiss) {
    if (typeof window.Razorpay !== "function") {
      onFailure({ description: "Razorpay Checkout could not be loaded." });
      return;
    }

    const checkout = new window.Razorpay({
      ...options,
      handler: onSuccess,
      modal: { ondismiss: onDismiss },
    });
    checkout.on("payment.failed", function (event) {
      const error = event && event.error ? event.error : event;
      onFailure(error || { description: "Payment failed." });
    });
    checkout.open();
  };
})();
