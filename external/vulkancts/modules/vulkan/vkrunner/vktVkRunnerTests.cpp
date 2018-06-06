/*------------------------------------------------------------------------
 * Vulkan Conformance Tests
 * ------------------------
 *
 * Copyright (c) 2018 Intel Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 *//*!
 * \file
 * \brief Functional tests using vkrunner
 *//*--------------------------------------------------------------------*/

#include "vktVkRunnerTests.hpp"
#include "vktTestCase.hpp"
#include "vktTestGroupUtil.hpp"
#include "tcuTestLog.hpp"

extern "C" {
#include <vkrunner/vkrunner.h>
}

namespace vkt
{
namespace vkrunner
{
namespace
{

typedef std::pair<std::string, std::string> TokenReplacement;

struct TestCaseData
{
	std::string 					filename;
	std::vector<TokenReplacement>	tokenReplacements;
};

class VkRunnerTestInstance : public TestInstance
{
public:
	VkRunnerTestInstance (Context& context, const TestCaseData& testCaseData)
		: TestInstance(context),
		  m_testCaseData(testCaseData)
	{
	}

	virtual tcu::TestStatus iterate (void);

private:
	TestCaseData m_testCaseData;

	static void errorCb(const char *message, void *user_data);
};

class VkRunnerTestCase : public TestCase
{
public:
	VkRunnerTestCase (tcu::TestContext&	testCtx,
					  const char*		filename,
					  const char*		name,
					  const char*		description)
		: TestCase(testCtx, name, description)
	{
		m_testCaseData.filename = filename;
	}

	void addTokenReplacement(const char *token,
							 const char *replacement)
	{
		m_testCaseData.tokenReplacements.push_back(TokenReplacement(token, replacement));
	}

	virtual TestInstance* createInstance (Context& ctx) const
	{
		return new VkRunnerTestInstance(ctx, m_testCaseData);
	}

private:
	TestCaseData m_testCaseData;
};

void VkRunnerTestInstance::errorCb(const char *message,
								   void *user_data)
{
	VkRunnerTestInstance *instance = (VkRunnerTestInstance *) user_data;

	instance->m_context.getTestContext().getLog()
		<< tcu::TestLog::Message
		<< message
		<< "\n"
		<< tcu::TestLog::EndMessage;
}

tcu::TestStatus VkRunnerTestInstance::iterate (void)
{
	std::string filename("vulkan/shader_test/");
	filename.append(m_testCaseData.filename);

	vr_config *config = vr_config_new();

	vr_config_set_user_data(config, this);
	vr_config_set_error_cb(config, errorCb);

	vr_config_add_script(config, filename.c_str());

	for (std::vector<TokenReplacement>::iterator it = m_testCaseData.tokenReplacements.begin();
		 it != m_testCaseData.tokenReplacements.end();
		 ++it) {
		vr_config_add_token_replacement(config,
										it->first.c_str(),
										it->second.c_str());
	}

	vr_result res = vr_execute(config);
	vr_config_free(config);

	switch (res) {
	case VR_RESULT_FAIL:
		return tcu::TestStatus::fail("Fail");
	case VR_RESULT_PASS:
		return tcu::TestStatus::pass("Pass");
	case VR_RESULT_SKIP:
		return tcu::TestStatus::incomplete();
	}

	return tcu::TestStatus::fail("Fail");
}

void createVkRunnerTests (tcu::TestCaseGroup* vkRunnerTests)
{
	tcu::TestContext&	testCtx	= vkRunnerTests->getTestContext();

	static const struct {
		const char *filename, *name, *description;
	} tests[] = {
		{ "ubo.shader_test", "ubo", "Example test setting values in a UBO" },
		{ "vertex-data.shader_test", "vertex-data", "Exampe test using a vertex data section" },
	};

	for (size_t i = 0; i < sizeof tests / sizeof tests[0]; i++) {
		VkRunnerTestCase *testCase = new VkRunnerTestCase(testCtx,
														  tests[i].filename,
														  tests[i].name,
														  tests[i].description);
		vkRunnerTests->addChild(testCase);
	}

	// Add some tests of the sqrt function using the templating mechanism
	for (int i = 1; i <= 8; i++) {
		std::stringstream testName;
		testName << "sqrt_" << i;
		VkRunnerTestCase *testCase = new VkRunnerTestCase(testCtx,
														  "sqrt.shader_test",
														  testName.str().c_str(),
														  "Example test using the templating mechanism");
		std::stringstream inputString;
		inputString << (i * i);
		std::stringstream outputString;
		outputString << i;
		testCase->addTokenReplacement("<INPUT>", inputString.str().c_str());
		testCase->addTokenReplacement("<OUTPUT>", outputString.str().c_str());
		vkRunnerTests->addChild(testCase);
	}
}

} // anonymous

tcu::TestCaseGroup* createTests (tcu::TestContext& testCtx)
{
	return createTestGroup(testCtx, "vkrunner", "VkRunner Tests", createVkRunnerTests);
}

} // vkrunner
} // vkt
