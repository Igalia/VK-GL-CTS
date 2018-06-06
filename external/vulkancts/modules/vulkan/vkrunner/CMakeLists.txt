# dEQP-VK.vkrunner

include_directories(.. ${PROJECT_SOURCE_DIR}/external/vkrunner/src)

set(DEQP_VK_VKRUNNER_SRCS
	vktVkRunnerTests.cpp
	vktVkRunnerTests.hpp
	)

set(DEQP_VK_VKRUNNER_LIBS
	tcutil
	vkutil
        vkrunner
	)

add_library(deqp-vk-vkrunner STATIC ${DEQP_VK_VKRUNNER_SRCS})
target_link_libraries(deqp-vk-vkrunner ${DEQP_VK_VKRUNNER_LIBS})
