// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
#pragma once

#ifdef CHIAKI_IS_MAC_APPSTORE

#include <QObject>

#include "settings.h"

class DonationManager;

// Mac App Store: dispatches `SKStoreReviewController.requestReview` once per cold launch on
// the first `Qt::ApplicationActive` transition. Eligibility is gated by cumulative stream time
// (10 min first, +60 min between prompts). All StoreKit symbols live in appreviewbridge.mm.
class AppReviewManager : public QObject
{
    Q_OBJECT

public:
    explicit AppReviewManager(Settings *settings, DonationManager *donationManager, QObject *parent = nullptr);

    /// Arms a one-shot listener for the next `Qt::ApplicationActive` transition. Idempotent.
    void armOnNextActivation();

private:
    void requestReviewIfEligible();

    Settings *m_settings;
    DonationManager *m_donationManager;
    QMetaObject::Connection m_activationConn;
    bool m_requestedThisLaunch = false;
    bool m_armed = false;
};

#endif // CHIAKI_IS_MAC_APPSTORE
