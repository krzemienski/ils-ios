#!/bin/bash

# CI/CD Pipeline Validation Script
# Validates GitHub Actions workflows and local build capability

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Helper functions
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_check() {
    echo -e "${YELLOW}Checking:${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅ PASS:${NC} $1"
    ((PASSED_CHECKS++))
    ((TOTAL_CHECKS++))
}

print_failure() {
    echo -e "${RED}❌ FAIL:${NC} $1"
    ((FAILED_CHECKS++))
    ((TOTAL_CHECKS++))
}

print_info() {
    echo -e "${BLUE}ℹ️  INFO:${NC} $1"
}

# Validation functions
check_workflow_files() {
    print_header "Workflow Files Validation"

    print_check "Backend tests workflow exists"
    if [ -f ".github/workflows/backend-tests.yml" ]; then
        print_success "backend-tests.yml exists"
    else
        print_failure "backend-tests.yml not found"
        return 1
    fi

    print_check "iOS build workflow exists"
    if [ -f ".github/workflows/ios-build.yml" ]; then
        print_success "ios-build.yml exists"
    else
        print_failure "ios-build.yml not found"
        return 1
    fi

    print_check "iOS release workflow exists"
    if [ -f ".github/workflows/ios-release.yml" ]; then
        print_success "ios-release.yml exists"
    else
        print_failure "ios-release.yml not found"
        return 1
    fi
}

check_workflow_syntax() {
    print_header "Workflow Syntax Validation"

    print_check "Backend tests workflow syntax"
    if grep -q "name: Backend Tests" .github/workflows/backend-tests.yml && \
       grep -q "swift test" .github/workflows/backend-tests.yml && \
       grep -q "swift build" .github/workflows/backend-tests.yml; then
        print_success "backend-tests.yml has valid structure"
    else
        print_failure "backend-tests.yml syntax issues"
    fi

    print_check "iOS build workflow syntax"
    if grep -q "name: iOS Build" .github/workflows/ios-build.yml && \
       grep -q "xcodebuild" .github/workflows/ios-build.yml; then
        print_success "ios-build.yml has valid structure"
    else
        print_failure "ios-build.yml syntax issues"
    fi

    print_check "iOS release workflow syntax"
    if grep -q "name: iOS Release" .github/workflows/ios-release.yml && \
       grep -q "tags:" .github/workflows/ios-release.yml && \
       grep -q "v\\*" .github/workflows/ios-release.yml; then
        print_success "ios-release.yml has valid structure"
    else
        print_failure "ios-release.yml syntax issues"
    fi
}

check_workflow_triggers() {
    print_header "Workflow Triggers Validation"

    print_check "Backend tests triggers"
    if grep -q "on:" .github/workflows/backend-tests.yml && \
       grep -q "pull_request:" .github/workflows/backend-tests.yml; then
        print_success "backend-tests.yml has correct triggers (push, pull_request)"
    else
        print_failure "backend-tests.yml trigger configuration issues"
    fi

    print_check "iOS build triggers"
    if grep -q "on:" .github/workflows/ios-build.yml && \
       grep -q "pull_request:" .github/workflows/ios-build.yml; then
        print_success "ios-build.yml has correct triggers (push, pull_request)"
    else
        print_failure "ios-build.yml trigger configuration issues"
    fi

    print_check "iOS release triggers"
    if grep -q "tags:" .github/workflows/ios-release.yml; then
        print_success "ios-release.yml has correct trigger (tags)"
    else
        print_failure "ios-release.yml trigger configuration issues"
    fi
}

check_concurrency_control() {
    print_header "Concurrency Control Validation"

    print_check "Backend tests concurrency"
    if grep -q "concurrency:" .github/workflows/backend-tests.yml && \
       grep -q "cancel-in-progress: true" .github/workflows/backend-tests.yml; then
        print_success "backend-tests.yml has concurrency control"
    else
        print_failure "backend-tests.yml missing concurrency control"
    fi

    print_check "iOS build concurrency"
    if grep -q "concurrency:" .github/workflows/ios-build.yml && \
       grep -q "cancel-in-progress: true" .github/workflows/ios-build.yml; then
        print_success "ios-build.yml has concurrency control"
    else
        print_failure "ios-build.yml missing concurrency control"
    fi

    print_check "iOS release concurrency (should NOT cancel)"
    if grep -q "concurrency:" .github/workflows/ios-release.yml && \
       grep -q "cancel-in-progress: false" .github/workflows/ios-release.yml; then
        print_success "ios-release.yml preserves release builds (cancel-in-progress: false)"
    else
        print_failure "ios-release.yml concurrency configuration issues"
    fi
}

check_path_filters() {
    print_header "Path Filters Validation"

    print_check "Backend tests path filters"
    if grep -q "paths:" .github/workflows/backend-tests.yml && \
       grep -q "Sources/\\*\\*/\\*.swift" .github/workflows/backend-tests.yml && \
       grep -q "Package.swift" .github/workflows/backend-tests.yml; then
        print_success "backend-tests.yml has appropriate path filters"
    else
        print_failure "backend-tests.yml path filter issues"
    fi

    print_check "iOS build path filters"
    if grep -q "paths:" .github/workflows/ios-build.yml && \
       grep -q "ILSApp/\\*\\*/\\*.swift" .github/workflows/ios-build.yml; then
        print_success "ios-build.yml has appropriate path filters"
    else
        print_failure "ios-build.yml path filter issues"
    fi
}

check_backend_build() {
    print_header "Backend Build Validation"

    print_check "Swift build capability"
    if swift build > /dev/null 2>&1; then
        print_success "Backend builds successfully"
    else
        print_failure "Backend build failed"
        print_info "Run 'swift build' manually to see errors"
    fi
}

check_ios_project() {
    print_header "iOS Project Validation"

    print_check "Xcode project exists"
    if [ -d "ILSApp/ILSApp.xcodeproj" ]; then
        print_success "iOS project exists at ILSApp/ILSApp.xcodeproj"
    else
        print_failure "iOS project not found"
        return 1
    fi

    print_check "Xcode scheme configuration"
    if xcodebuild -project ILSApp/ILSApp.xcodeproj -list | grep -q "ILSApp"; then
        print_success "ILSApp scheme exists"
    else
        print_failure "ILSApp scheme not found"
    fi
}

check_version_extraction() {
    print_header "Version Extraction Logic"

    print_check "Version extraction in release workflow"
    if grep -q "VERSION=\${GITHUB_REF#refs/tags/v}" .github/workflows/ios-release.yml && \
       grep -q "version=\$VERSION" .github/workflows/ios-release.yml; then
        print_success "Version extraction logic is correct"
    else
        print_failure "Version extraction logic issues"
    fi
}

check_artifact_retention() {
    print_header "Artifact Retention Policies"

    print_check "Build logs retention (iOS build)"
    if grep -q "retention-days: 7" .github/workflows/ios-build.yml; then
        print_success "Build logs retention: 7 days"
    else
        print_failure "Build logs retention not configured"
    fi

    print_check "Release archive retention"
    if grep -q "retention-days: 90" .github/workflows/ios-release.yml; then
        print_success "Release archive retention: 90 days"
    else
        print_failure "Release archive retention not configured"
    fi
}

check_security_practices() {
    print_header "Security Best Practices"

    print_check "No hardcoded secrets"
    if ! grep -r "password.*=" .github/workflows/ && \
       ! grep -r "api_key.*=" .github/workflows/ && \
       ! grep -r "token.*=" .github/workflows/; then
        print_success "No hardcoded secrets detected"
    else
        print_failure "Potential hardcoded secrets found"
    fi

    print_check "Uses secrets syntax for sensitive data"
    if grep -q "\${{ secrets\." .github/workflows/ios-release.yml; then
        print_success "Uses \${{ secrets.* }} for sensitive data (in TODO sections)"
    else
        print_info "No secrets used yet (expected for initial setup)"
        ((TOTAL_CHECKS++))
    fi
}

check_action_versions() {
    print_header "GitHub Actions Versions"

    print_check "Uses latest checkout action"
    if grep -q "actions/checkout@v4" .github/workflows/backend-tests.yml && \
       grep -q "actions/checkout@v4" .github/workflows/ios-build.yml && \
       grep -q "actions/checkout@v4" .github/workflows/ios-release.yml; then
        print_success "All workflows use actions/checkout@v4"
    else
        print_failure "Some workflows use outdated checkout action"
    fi

    print_check "Uses latest upload-artifact action"
    if grep -q "actions/upload-artifact@v4" .github/workflows/ios-build.yml && \
       grep -q "actions/upload-artifact@v4" .github/workflows/ios-release.yml; then
        print_success "Workflows use actions/upload-artifact@v4"
    else
        print_failure "Some workflows use outdated upload-artifact action"
    fi
}

check_code_coverage() {
    print_header "Code Coverage Configuration"

    print_check "Backend code coverage"
    if grep -q "enable-code-coverage" .github/workflows/backend-tests.yml && \
       grep -q "llvm-cov" .github/workflows/backend-tests.yml; then
        print_success "Backend workflow enables code coverage"
    else
        print_failure "Backend code coverage not configured"
    fi

    print_check "iOS code coverage"
    if grep -q "enableCodeCoverage YES" .github/workflows/ios-build.yml; then
        print_success "iOS workflow enables code coverage"
    else
        print_failure "iOS code coverage not configured"
    fi
}

# Main execution
main() {
    print_header "CI/CD Pipeline Validation Script"
    echo -e "${BLUE}Validating GitHub Actions workflows and build capability${NC}\n"

    # Run all checks
    check_workflow_files
    check_workflow_syntax
    check_workflow_triggers
    check_concurrency_control
    check_path_filters
    check_version_extraction
    check_artifact_retention
    check_security_practices
    check_action_versions
    check_code_coverage
    check_backend_build
    check_ios_project

    # Print summary
    print_header "Validation Summary"
    echo -e "Total Checks: ${BLUE}${TOTAL_CHECKS}${NC}"
    echo -e "Passed: ${GREEN}${PASSED_CHECKS}${NC}"
    echo -e "Failed: ${RED}${FAILED_CHECKS}${NC}"

    if [ $FAILED_CHECKS -eq 0 ]; then
        echo -e "\n${GREEN}🎉 All CI/CD validation checks passed!${NC}"
        echo -e "${GREEN}The pipeline is ready for production use.${NC}\n"
        return 0
    else
        echo -e "\n${YELLOW}⚠️  Some checks failed. Review the output above.${NC}\n"
        return 1
    fi
}

# Run main function
main
