use std::net::{SocketAddr, ToSocketAddrs};

use anyhow::{anyhow, Context};
use prost::Message;
use rand::Rng;
use s2n_quic::{client::Connect, Client};
use tokio::io::{AsyncReadExt, AsyncWriteExt};

use crate::protocol::{v1, MAX_FRAME_BYTES, PROTOCOL_MAJOR};

#[derive(Debug)]
#[flutter_rust_bridge::frb]
pub struct ServerHello {
    pub success: bool,
    pub protocol_major: u32,
    pub server_build: String,
    pub maximum_frame_bytes: u32,
    pub capabilities: Vec<String>,
    pub error_message: Option<String>,
}

#[derive(Debug)]
#[flutter_rust_bridge::frb]
pub struct OtpChallenge {
    pub success: bool,
    pub challenge_id: String,
    pub expires_in_seconds: u32,
    pub error_message: Option<String>,
}
#[derive(Debug)]
#[flutter_rust_bridge::frb]
pub struct AuthTokens {
    pub success: bool,
    pub transport_unavailable: bool,
    pub access_token: String,
    pub refresh_token: String,
    pub user_id: String,
    pub error_message: Option<String>,
}
#[derive(Debug)]
#[flutter_rust_bridge::frb]
pub struct NetworkResult {
    pub success: bool,
    pub error_message: Option<String>,
}

#[derive(Debug)]
#[flutter_rust_bridge::frb]
pub struct PendingLoanInvitation {
    pub success: bool,
    pub invitation_id: String,
    pub linked_to_existing_account: bool,
    pub error_message: Option<String>,
}

#[derive(Debug)]
#[flutter_rust_bridge::frb]
pub struct SharedRepayment {
    pub id: String,
    pub event_type: String,
    pub amount_minor: i64,
    pub currency: String,
    pub currency_scale: u32,
    pub payment_date: String,
    pub recorded_at: String,
    pub payment_method: String,
    pub reverses_event_id: String,
}

#[derive(Debug)]
#[flutter_rust_bridge::frb]
pub struct ChatCredentials {
    pub success: bool,
    pub jid: String,
    pub access_token: String,
    pub expires_at_ms: i64,
    pub websocket_url: String,
    pub error_message: Option<String>,
}

#[derive(Debug)]
#[flutter_rust_bridge::frb]
pub struct PublicLender {
    pub id: String,
    pub display_name: String,
    pub locality: String,
    pub city: String,
    pub postal_code: String,
    pub country_code: String,
    pub minimum_loan_minor: i64,
    pub maximum_loan_minor: i64,
    pub currency: String,
    pub currency_scale: u32,
    pub categories: Vec<String>,
    pub verification_level: String,
    pub available: bool,
    pub public_description: String,
}

impl From<v1::PublicLenderProfile> for PublicLender {
    fn from(profile: v1::PublicLenderProfile) -> Self {
        Self {
            id: profile.id,
            display_name: profile.display_name,
            locality: profile.locality,
            city: profile.city,
            postal_code: profile.postal_code,
            country_code: profile.country_code,
            minimum_loan_minor: profile.minimum_loan_minor,
            maximum_loan_minor: profile.maximum_loan_minor,
            currency: profile.currency,
            currency_scale: profile.currency_scale,
            categories: profile.categories,
            verification_level: profile.verification_level,
            available: profile.available,
            public_description: profile.public_description,
        }
    }
}

#[flutter_rust_bridge::frb]
pub async fn create_pending_loan(
    server_address: String,
    server_name: String,
    trusted_certificate_pem: String,
    device_id: String,
    access_token: String,
    workspace_id: String,
    operation_id: String,
    borrower_phone_e164: String,
    borrower_name: String,
    loan_payload_json: Vec<u8>,
) -> PendingLoanInvitation {
    match send_request(
        &server_address,
        &server_name,
        &trusted_certificate_pem,
        &device_id,
        access_token,
        v1::request::Payload::CreatePendingLoan(v1::CreatePendingLoanRequest {
            workspace_id,
            operation_id,
            borrower_phone_e164,
            borrower_name,
            loan_payload_json,
        }),
    )
    .await
    {
        Ok(v1::response::Result::CreatePendingLoan(value)) => PendingLoanInvitation {
            success: true,
            invitation_id: value.invitation_id,
            linked_to_existing_account: value.linked_to_existing_account,
            error_message: None,
        },
        Ok(v1::response::Result::Error(value)) => PendingLoanInvitation {
            success: false,
            invitation_id: String::new(),
            linked_to_existing_account: false,
            error_message: Some(value.message),
        },
        Ok(_) => PendingLoanInvitation {
            success: false,
            invitation_id: String::new(),
            linked_to_existing_account: false,
            error_message: Some("unexpected server response".into()),
        },
        Err(error) => PendingLoanInvitation {
            success: false,
            invitation_id: String::new(),
            linked_to_existing_account: false,
            error_message: Some(error.to_string()),
        },
    }
}

#[derive(Debug)]
#[flutter_rust_bridge::frb]
pub struct SharedLoanSummary {
    pub loan_id: String,
    pub lender_party_id: String,
    pub borrower_party_id: String,
    pub principal_minor: i64,
    pub currency: String,
    pub currency_scale: u32,
    pub lifecycle: String,
    pub loan_date: String,
    pub maturity_date: String,
    pub repayments: Vec<SharedRepayment>,
}

#[derive(Debug)]
#[flutter_rust_bridge::frb]
pub struct SharedLoanListResult {
    pub success: bool,
    pub loans: Vec<SharedLoanSummary>,
    pub error_message: Option<String>,
}

#[flutter_rust_bridge::frb]
pub async fn push_financial_event(
    server_address: String,
    server_name: String,
    trusted_certificate_pem: String,
    device_id: String,
    access_token: String,
    workspace_id: String,
    operation_id: String,
    loan_id: String,
    event_type: String,
    amount_minor: String,
    currency: String,
    currency_scale: u32,
    effective_date: String,
    payment_method: Option<String>,
    reference_number: Option<String>,
    reverses_event_id: Option<String>,
    reason: Option<String>,
    principal_minor: Option<String>,
    loan_date: Option<String>,
) -> NetworkResult {
    let amount_minor = match amount_minor.parse::<i64>() {
        Ok(value) if value > 0 => value,
        _ => {
            return NetworkResult {
                success: false,
                error_message: Some("invalid repayment amount".into()),
            }
        }
    };
    let payload = serde_json::json!({
        "loan_id": loan_id,
        "type": event_type,
        "amount_minor": amount_minor,
        "currency": currency,
        "currency_scale": currency_scale,
        "effective_date": effective_date,
        "payment_method": payment_method,
        "reference_number": reference_number,
        "reverses_event_id": reverses_event_id,
        "reason": reason,
        "principal_minor": principal_minor.and_then(|value| value.parse::<i64>().ok()),
        "loan_date": loan_date,
    });
    simple_network_result(
        send_request(
            &server_address,
            &server_name,
            &trusted_certificate_pem,
            &device_id,
            access_token,
            v1::request::Payload::PushMutation(v1::PushMutationRequest {
                workspace_id,
                operation_id: operation_id.clone(),
                entity_type: "financial_event".into(),
                entity_id: operation_id,
                operation: "create".into(),
                expected_revision: 0,
                payload_json: serde_json::to_vec(&payload).unwrap_or_default(),
            }),
        )
        .await,
        |result| matches!(result, v1::response::Result::PushMutation(_)),
    )
}

#[flutter_rust_bridge::frb]
pub async fn list_shared_loans(
    server_address: String,
    server_name: String,
    trusted_certificate_pem: String,
    device_id: String,
    access_token: String,
    limit: u32,
) -> SharedLoanListResult {
    match send_request(
        &server_address,
        &server_name,
        &trusted_certificate_pem,
        &device_id,
        access_token,
        v1::request::Payload::SharedLoanList(v1::SharedLoanListRequest { limit }),
    )
    .await
    {
        Ok(v1::response::Result::SharedLoanList(value)) => SharedLoanListResult {
            success: true,
            loans: value
                .loans
                .into_iter()
                .map(|loan| SharedLoanSummary {
                    loan_id: loan.loan_id,
                    lender_party_id: loan.lender_party_id,
                    borrower_party_id: loan.borrower_party_id,
                    principal_minor: loan.principal_minor,
                    currency: loan.currency,
                    currency_scale: loan.currency_scale,
                    lifecycle: loan.lifecycle,
                    loan_date: loan.loan_date,
                    maturity_date: loan.maturity_date,
                    repayments: loan
                        .repayments
                        .into_iter()
                        .map(|event| SharedRepayment {
                            id: event.id,
                            event_type: event.r#type,
                            amount_minor: event.amount_minor,
                            currency: event.currency,
                            currency_scale: event.currency_scale,
                            payment_date: event.payment_date,
                            recorded_at: event.recorded_at,
                            payment_method: event.payment_method,
                            reverses_event_id: event.reverses_event_id,
                        })
                        .collect(),
                })
                .collect(),
            error_message: None,
        },
        Ok(v1::response::Result::Error(value)) => SharedLoanListResult {
            success: false,
            loans: Vec::new(),
            error_message: Some(value.message),
        },
        Ok(_) => SharedLoanListResult {
            success: false,
            loans: Vec::new(),
            error_message: Some("unexpected server response".into()),
        },
        Err(error) => SharedLoanListResult {
            success: false,
            loans: Vec::new(),
            error_message: Some(error.to_string()),
        },
    }
}

#[derive(Debug)]
#[flutter_rust_bridge::frb]
pub struct MyLenderProfile {
    pub success: bool,
    pub profile: Option<PublicLender>,
    pub published: bool,
    pub error_message: Option<String>,
}

#[flutter_rust_bridge::frb]
pub async fn my_lender_profile(
    server_address: String,
    server_name: String,
    trusted_certificate_pem: String,
    device_id: String,
    access_token: String,
) -> MyLenderProfile {
    match send_request(
        &server_address,
        &server_name,
        &trusted_certificate_pem,
        &device_id,
        access_token,
        v1::request::Payload::MyLenderProfile(v1::MyLenderProfileRequest {}),
    )
    .await
    {
        Ok(v1::response::Result::MyLenderProfile(value)) => MyLenderProfile {
            success: true,
            profile: value.profile.map(PublicLender::from),
            published: value.published,
            error_message: None,
        },
        Ok(v1::response::Result::Error(value)) => MyLenderProfile {
            success: false,
            profile: None,
            published: false,
            error_message: Some(value.message),
        },
        Ok(_) => MyLenderProfile {
            success: false,
            profile: None,
            published: false,
            error_message: Some("unexpected server response".into()),
        },
        Err(cause) => MyLenderProfile {
            success: false,
            profile: None,
            published: false,
            error_message: Some(cause.to_string()),
        },
    }
}

#[derive(Debug)]
#[flutter_rust_bridge::frb]
pub struct LenderSearchResult {
    pub success: bool,
    pub lenders: Vec<PublicLender>,
    pub next_after_id: String,
    pub error_message: Option<String>,
}

#[derive(Debug)]
#[flutter_rust_bridge::frb]
pub struct AccountBootstrap {
    pub success: bool,
    pub user_id: String,
    pub workspace_id: String,
    pub self_party_id: String,
    pub phone_e164: String,
    pub preferred_language: String,
    pub error_message: Option<String>,
}

#[flutter_rust_bridge::frb]
pub async fn account_bootstrap(
    server_address: String,
    server_name: String,
    trusted_certificate_pem: String,
    device_id: String,
    access_token: String,
) -> AccountBootstrap {
    match send_request(
        &server_address,
        &server_name,
        &trusted_certificate_pem,
        &device_id,
        access_token,
        v1::request::Payload::AccountBootstrap(v1::AccountBootstrapRequest {}),
    )
    .await
    {
        Ok(v1::response::Result::AccountBootstrap(value)) => AccountBootstrap {
            success: true,
            user_id: value.user_id,
            workspace_id: value.workspace_id,
            self_party_id: value.self_party_id,
            phone_e164: value.phone_e164,
            preferred_language: value.preferred_language,
            error_message: None,
        },
        Ok(v1::response::Result::Error(value)) => AccountBootstrap {
            success: false,
            user_id: String::new(),
            workspace_id: String::new(),
            self_party_id: String::new(),
            phone_e164: String::new(),
            preferred_language: String::new(),
            error_message: Some(value.message),
        },
        Ok(_) => AccountBootstrap {
            success: false,
            user_id: String::new(),
            workspace_id: String::new(),
            self_party_id: String::new(),
            phone_e164: String::new(),
            preferred_language: String::new(),
            error_message: Some("unexpected server response".into()),
        },
        Err(cause) => AccountBootstrap {
            success: false,
            user_id: String::new(),
            workspace_id: String::new(),
            self_party_id: String::new(),
            phone_e164: String::new(),
            preferred_language: String::new(),
            error_message: Some(cause.to_string()),
        },
    }
}

#[flutter_rust_bridge::frb]
pub async fn publish_public_lender(
    server_address: String,
    server_name: String,
    trusted_certificate_pem: String,
    device_id: String,
    access_token: String,
    display_name: String,
    locality: String,
    city: String,
    postal_code: String,
    country_code: String,
    minimum_loan_minor: String,
    maximum_loan_minor: String,
    currency: String,
    currency_scale: u32,
    categories: Vec<String>,
    available: bool,
    published: bool,
    public_description: String,
) -> NetworkResult {
    let minimum = match minimum_loan_minor.parse::<i64>() {
        Ok(value) => value,
        Err(_) => {
            return NetworkResult {
                success: false,
                error_message: Some("invalid minimum loan amount".into()),
            }
        }
    };
    let maximum = match maximum_loan_minor.parse::<i64>() {
        Ok(value) => value,
        Err(_) => {
            return NetworkResult {
                success: false,
                error_message: Some("invalid maximum loan amount".into()),
            }
        }
    };
    simple_network_result(
        send_request(
            &server_address,
            &server_name,
            &trusted_certificate_pem,
            &device_id,
            access_token,
            v1::request::Payload::PublishLenderProfile(v1::PublishLenderProfileRequest {
                display_name,
                locality,
                city,
                postal_code,
                country_code,
                minimum_loan_minor: minimum,
                maximum_loan_minor: maximum,
                currency,
                currency_scale,
                categories,
                available,
                published,
                public_description,
            }),
        )
        .await,
        |result| matches!(result, v1::response::Result::PublishLenderProfile(_)),
    )
}

#[flutter_rust_bridge::frb]
pub async fn search_public_lenders(
    server_address: String,
    server_name: String,
    trusted_certificate_pem: String,
    device_id: String,
    access_token: String,
    area: u32,
    query: String,
    limit: u32,
    after_id: String,
) -> LenderSearchResult {
    let area = match area {
        1 => v1::LenderSearchArea::Locality,
        2 => v1::LenderSearchArea::City,
        3 => v1::LenderSearchArea::PostalCode,
        _ => {
            return LenderSearchResult {
                success: false,
                lenders: Vec::new(),
                next_after_id: String::new(),
                error_message: Some("invalid lender search area".into()),
            };
        }
    };
    match send_request(
        &server_address,
        &server_name,
        &trusted_certificate_pem,
        &device_id,
        access_token,
        v1::request::Payload::SearchLenders(v1::SearchLendersRequest {
            area: area as i32,
            query,
            limit,
            after_id,
        }),
    )
    .await
    {
        Ok(v1::response::Result::SearchLenders(value)) => LenderSearchResult {
            success: true,
            lenders: value.lenders.into_iter().map(PublicLender::from).collect(),
            next_after_id: value.next_after_id,
            error_message: None,
        },
        Ok(v1::response::Result::Error(value)) => LenderSearchResult {
            success: false,
            lenders: Vec::new(),
            next_after_id: String::new(),
            error_message: Some(value.message),
        },
        Ok(_) => LenderSearchResult {
            success: false,
            lenders: Vec::new(),
            next_after_id: String::new(),
            error_message: Some("unexpected server response".into()),
        },
        Err(cause) => LenderSearchResult {
            success: false,
            lenders: Vec::new(),
            next_after_id: String::new(),
            error_message: Some(cause.to_string()),
        },
    }
}

#[flutter_rust_bridge::frb]
pub async fn report_public_lender(
    server_address: String,
    server_name: String,
    trusted_certificate_pem: String,
    device_id: String,
    access_token: String,
    profile_id: String,
    reason: String,
) -> NetworkResult {
    simple_network_result(
        send_request(
            &server_address,
            &server_name,
            &trusted_certificate_pem,
            &device_id,
            access_token,
            v1::request::Payload::ReportLenderProfile(v1::ReportLenderProfileRequest {
                profile_id,
                reason,
            }),
        )
        .await,
        |result| matches!(result, v1::response::Result::ReportLenderProfile(_)),
    )
}

#[flutter_rust_bridge::frb]
pub async fn block_public_lender(
    server_address: String,
    server_name: String,
    trusted_certificate_pem: String,
    device_id: String,
    access_token: String,
    profile_id: String,
) -> NetworkResult {
    simple_network_result(
        send_request(
            &server_address,
            &server_name,
            &trusted_certificate_pem,
            &device_id,
            access_token,
            v1::request::Payload::BlockLenderProfile(v1::BlockLenderProfileRequest { profile_id }),
        )
        .await,
        |result| matches!(result, v1::response::Result::BlockLenderProfile(_)),
    )
}

fn simple_network_result(
    result: anyhow::Result<v1::response::Result>,
    expected: impl FnOnce(&v1::response::Result) -> bool,
) -> NetworkResult {
    match result {
        Ok(value) if expected(&value) => NetworkResult {
            success: true,
            error_message: None,
        },
        Ok(v1::response::Result::Error(value)) => NetworkResult {
            success: false,
            error_message: Some(value.message),
        },
        Ok(_) => NetworkResult {
            success: false,
            error_message: Some("unexpected server response".into()),
        },
        Err(cause) => NetworkResult {
            success: false,
            error_message: Some(cause.to_string()),
        },
    }
}

#[flutter_rust_bridge::frb]
pub async fn request_chat_credentials(
    server_address: String,
    server_name: String,
    trusted_certificate_pem: String,
    device_id: String,
    access_token: String,
) -> ChatCredentials {
    match send_request(
        &server_address,
        &server_name,
        &trusted_certificate_pem,
        &device_id,
        access_token,
        v1::request::Payload::ChatToken(v1::ChatTokenRequest {}),
    )
    .await
    {
        Ok(v1::response::Result::ChatToken(v)) => ChatCredentials {
            success: true,
            jid: v.jid,
            access_token: v.access_token,
            expires_at_ms: v.expires_at_ms,
            websocket_url: v.websocket_url,
            error_message: None,
        },
        Ok(v1::response::Result::Error(v)) => ChatCredentials {
            success: false,
            jid: String::new(),
            access_token: String::new(),
            expires_at_ms: 0,
            websocket_url: String::new(),
            error_message: Some(v.message),
        },
        Ok(_) => ChatCredentials {
            success: false,
            jid: String::new(),
            access_token: String::new(),
            expires_at_ms: 0,
            websocket_url: String::new(),
            error_message: Some("unexpected server response".into()),
        },
        Err(e) => ChatCredentials {
            success: false,
            jid: String::new(),
            access_token: String::new(),
            expires_at_ms: 0,
            websocket_url: String::new(),
            error_message: Some(e.to_string()),
        },
    }
}

#[flutter_rust_bridge::frb]
pub async fn request_otp(
    server_address: String,
    server_name: String,
    trusted_certificate_pem: String,
    device_id: String,
    phone_e164: String,
) -> OtpChallenge {
    match send_request(
        &server_address,
        &server_name,
        &trusted_certificate_pem,
        &device_id,
        String::new(),
        v1::request::Payload::RequestOtp(v1::RequestOtpRequest { phone_e164 }),
    )
    .await
    {
        Ok(v1::response::Result::RequestOtp(v)) => OtpChallenge {
            success: true,
            challenge_id: v.challenge_id,
            expires_in_seconds: v.expires_in_seconds,
            error_message: None,
        },
        Ok(v1::response::Result::Error(v)) => OtpChallenge {
            success: false,
            challenge_id: String::new(),
            expires_in_seconds: 0,
            error_message: Some(v.message),
        },
        Ok(_) => OtpChallenge {
            success: false,
            challenge_id: String::new(),
            expires_in_seconds: 0,
            error_message: Some("unexpected server response".into()),
        },
        Err(e) => OtpChallenge {
            success: false,
            challenge_id: String::new(),
            expires_in_seconds: 0,
            error_message: Some(e.to_string()),
        },
    }
}

#[flutter_rust_bridge::frb]
pub async fn verify_otp(
    server_address: String,
    server_name: String,
    trusted_certificate_pem: String,
    device_id: String,
    challenge_id: String,
    phone_e164: String,
    otp: String,
    preferred_language: String,
) -> AuthTokens {
    match send_request(
        &server_address,
        &server_name,
        &trusted_certificate_pem,
        &device_id,
        String::new(),
        v1::request::Payload::VerifyOtp(v1::VerifyOtpRequest {
            challenge_id,
            phone_e164,
            otp,
            preferred_language,
        }),
    )
    .await
    {
        Ok(v1::response::Result::VerifyOtp(v)) => AuthTokens {
            success: true,
            transport_unavailable: false,
            access_token: v.access_token,
            refresh_token: v.refresh_token,
            user_id: v.user_id,
            error_message: None,
        },
        Ok(v1::response::Result::Error(v)) => AuthTokens {
            success: false,
            transport_unavailable: false,
            access_token: String::new(),
            refresh_token: String::new(),
            user_id: String::new(),
            error_message: Some(v.message),
        },
        Ok(_) => AuthTokens {
            success: false,
            transport_unavailable: false,
            access_token: String::new(),
            refresh_token: String::new(),
            user_id: String::new(),
            error_message: Some("unexpected server response".into()),
        },
        Err(e) => AuthTokens {
            success: false,
            transport_unavailable: true,
            access_token: String::new(),
            refresh_token: String::new(),
            user_id: String::new(),
            error_message: Some(e.to_string()),
        },
    }
}

#[flutter_rust_bridge::frb]
pub async fn update_language(
    server_address: String,
    server_name: String,
    trusted_certificate_pem: String,
    device_id: String,
    access_token: String,
    preferred_language: String,
) -> NetworkResult {
    match send_request(
        &server_address,
        &server_name,
        &trusted_certificate_pem,
        &device_id,
        access_token,
        v1::request::Payload::UpdateLanguage(v1::UpdateLanguageRequest { preferred_language }),
    )
    .await
    {
        Ok(v1::response::Result::UpdateLanguage(_)) => NetworkResult {
            success: true,
            error_message: None,
        },
        Ok(v1::response::Result::Error(v)) => NetworkResult {
            success: false,
            error_message: Some(v.message),
        },
        Ok(_) => NetworkResult {
            success: false,
            error_message: Some("unexpected server response".into()),
        },
        Err(e) => NetworkResult {
            success: false,
            error_message: Some(e.to_string()),
        },
    }
}

#[flutter_rust_bridge::frb]
pub async fn refresh_session(
    server_address: String,
    server_name: String,
    trusted_certificate_pem: String,
    device_id: String,
    refresh_token: String,
) -> AuthTokens {
    match send_request(
        &server_address,
        &server_name,
        &trusted_certificate_pem,
        &device_id,
        String::new(),
        v1::request::Payload::RefreshToken(v1::RefreshTokenRequest { refresh_token }),
    )
    .await
    {
        Ok(v1::response::Result::RefreshToken(v)) => AuthTokens {
            success: true,
            transport_unavailable: false,
            access_token: v.access_token,
            refresh_token: v.refresh_token,
            user_id: String::new(),
            error_message: None,
        },
        Ok(v1::response::Result::Error(v)) => AuthTokens {
            success: false,
            transport_unavailable: false,
            access_token: String::new(),
            refresh_token: String::new(),
            user_id: String::new(),
            error_message: Some(v.message),
        },
        Ok(_) => AuthTokens {
            success: false,
            transport_unavailable: false,
            access_token: String::new(),
            refresh_token: String::new(),
            user_id: String::new(),
            error_message: Some("unexpected server response".into()),
        },
        Err(e) => AuthTokens {
            success: false,
            transport_unavailable: true,
            access_token: String::new(),
            refresh_token: String::new(),
            user_id: String::new(),
            error_message: Some(e.to_string()),
        },
    }
}

/// Revokes the current server-side session. Local credentials should only be
/// removed after success, or explicitly as a user-selected offline logout.
#[flutter_rust_bridge::frb]
pub async fn logout_session(
    server_address: String,
    server_name: String,
    trusted_certificate_pem: String,
    device_id: String,
    access_token: String,
) -> NetworkResult {
    match send_request(
        &server_address,
        &server_name,
        &trusted_certificate_pem,
        &device_id,
        access_token,
        v1::request::Payload::Logout(v1::LogoutRequest {}),
    )
    .await
    {
        Ok(v1::response::Result::Logout(_)) => NetworkResult {
            success: true,
            error_message: None,
        },
        Ok(v1::response::Result::Error(v)) => NetworkResult {
            success: false,
            error_message: Some(v.message),
        },
        Ok(_) => NetworkResult {
            success: false,
            error_message: Some("unexpected server response".into()),
        },
        Err(e) => NetworkResult {
            success: false,
            error_message: Some(e.to_string()),
        },
    }
}

async fn send_request(
    address: &str,
    name: &str,
    certificate: &str,
    device: &str,
    token: String,
    payload: v1::request::Payload,
) -> anyhow::Result<v1::response::Result> {
    let client = Client::builder()
        .with_tls(certificate)
        .map_err(|e| anyhow!(e.to_string()))?
        .with_io("0.0.0.0:0")
        .map_err(|e| anyhow!(e.to_string()))?
        .start()
        .map_err(|e| anyhow!(e.to_string()))?;
    let mut connection = client
        .connect(Connect::new(resolve_address(address)?).with_server_name(name))
        .await?;
    let mut stream = connection.open_bidirectional_stream().await?;
    let mut id = vec![0u8; 16];
    rand::rng().fill_bytes(&mut id);
    let request = v1::Request {
        protocol_major: PROTOCOL_MAJOR,
        request_id: id.clone(),
        device_id: device.into(),
        access_token: token,
        payload: Some(payload),
    };
    write_frame(&mut stream, &request.encode_to_vec()).await?;
    stream.shutdown().await?;
    let response = v1::Response::decode(read_frame(&mut stream).await?.as_slice())?;
    if response.request_id != id {
        return Err(anyhow!("server response request_id mismatch"));
    }
    response.result.context("server response missing result")
}

/// Negotiates the LoanX protocol through Rust so Flutter never owns QUIC or
/// Protobuf transport details. `trusted_certificate_pem` must authenticate
/// `server_name`; certificate validation is never disabled.
#[flutter_rust_bridge::frb]
pub async fn connect_and_hello(
    server_address: String,
    server_name: String,
    trusted_certificate_pem: String,
    device_id: String,
    client_build: String,
) -> ServerHello {
    match connect_and_hello_inner(
        server_address,
        server_name,
        trusted_certificate_pem,
        device_id,
        client_build,
    )
    .await
    {
        Ok(value) => value,
        Err(cause) => ServerHello {
            success: false,
            protocol_major: 0,
            server_build: String::new(),
            maximum_frame_bytes: 0,
            capabilities: Vec::new(),
            error_message: Some(cause.to_string()),
        },
    }
}

async fn connect_and_hello_inner(
    server_address: String,
    server_name: String,
    trusted_certificate_pem: String,
    device_id: String,
    client_build: String,
) -> anyhow::Result<ServerHello> {
    let address = resolve_address(&server_address)?;
    let client = Client::builder()
        .with_tls(trusted_certificate_pem.as_str())
        .map_err(|cause| anyhow!(cause.to_string()))?
        .with_io("0.0.0.0:0")
        .map_err(|cause| anyhow!(cause.to_string()))?
        .start()
        .map_err(|cause| anyhow!(cause.to_string()))?;
    let connect = Connect::new(address).with_server_name(server_name);
    let mut connection = client
        .connect(connect)
        .await
        .context("connect to LoanX server")?;
    let mut stream = connection
        .open_bidirectional_stream()
        .await
        .context("open request stream")?;

    let mut request_id = vec![0_u8; 16];
    rand::rng().fill_bytes(&mut request_id);
    let request = v1::Request {
        protocol_major: PROTOCOL_MAJOR,
        request_id: request_id.clone(),
        device_id,
        access_token: String::new(),
        payload: Some(v1::request::Payload::Hello(v1::HelloRequest {
            minimum_protocol_major: PROTOCOL_MAJOR,
            maximum_protocol_major: PROTOCOL_MAJOR,
            client_build,
            capabilities: vec!["ping".into()],
        })),
    };
    write_frame(&mut stream, &request.encode_to_vec()).await?;
    stream.shutdown().await.context("finish request")?;
    let bytes = read_frame(&mut stream).await?;
    let response = v1::Response::decode(bytes.as_slice()).context("decode server response")?;
    if response.request_id != request_id {
        return Err(anyhow!("server response request_id mismatch"));
    }
    if response.protocol_major != PROTOCOL_MAJOR {
        return Err(anyhow!("server selected an incompatible protocol major"));
    }

    match response.result {
        Some(v1::response::Result::Hello(value)) => Ok(ServerHello {
            success: true,
            protocol_major: value.selected_protocol_major,
            server_build: value.server_build,
            maximum_frame_bytes: value.maximum_frame_bytes,
            capabilities: value.capabilities,
            error_message: None,
        }),
        Some(v1::response::Result::Error(value)) => Err(anyhow!(
            "server protocol error {}: {}",
            value.code,
            value.message
        )),
        _ => Err(anyhow!("server returned an unexpected response payload")),
    }
}

fn resolve_address(value: &str) -> anyhow::Result<SocketAddr> {
    value
        .to_socket_addrs()
        .with_context(|| format!("resolve server address {value}"))?
        .next()
        .ok_or_else(|| anyhow!("server_address did not resolve"))
}
async fn write_frame(
    stream: &mut s2n_quic::stream::BidirectionalStream,
    frame: &[u8],
) -> anyhow::Result<()> {
    if frame.is_empty() || frame.len() > MAX_FRAME_BYTES {
        return Err(anyhow!("request frame is outside the allowed range"));
    }
    stream
        .write_u32(frame.len() as u32)
        .await
        .context("write request frame length")?;
    stream.write_all(frame).await.context("write request frame")
}
async fn read_frame(stream: &mut s2n_quic::stream::BidirectionalStream) -> anyhow::Result<Vec<u8>> {
    let length = stream
        .read_u32()
        .await
        .context("read response frame length")? as usize;
    if length == 0 || length > MAX_FRAME_BYTES {
        return Err(anyhow!("response frame is outside the allowed range"));
    }
    let mut bytes = vec![0; length];
    stream
        .read_exact(&mut bytes)
        .await
        .context("read response frame")?;
    Ok(bytes)
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn rejects_unresolvable_address() {
        assert!(resolve_address("not an address").is_err());
    }
}
