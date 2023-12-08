import logging
import os
from typing import Optional

from opencensus.ext.azure.log_exporter import AzureLogHandler
from opencensus.trace import config_integration
from opencensus.trace.samplers import AlwaysOnSampler
from opencensus.trace.tracer import Tracer

from core.config import VERSION

UNWANTED_LOGGERS = [
    "azure.core.pipeline.policies.http_logging_policy",
    "azure.eventhub._eventprocessor.event_processor",
    "azure.identity.aio._credentials.managed_identity",
    "azure.identity.aio._credentials.environment",
    "azure.identity.aio._internal.get_token_mixin",
    "azure.identity.aio._internal.decorators",
    "azure.identity.aio._credentials.chained",
    "azure.identity",
    "msal.token_cache"
    # Remove these once the following PR is merged:
    # https://github.com/Azure/azure-sdk-for-python/pull/30832
    # Issue: https://github.com/microsoft/AzureTRE/issues/3766
    "azure.servicebus._pyamqp.aio._session_async"
]

LOGGERS_FOR_ERRORS_ONLY = [
    "urllib3.connectionpool",
    "uamqp",
    "uamqp.authentication.cbs_auth_async",
    "uamqp.async_ops.client_async",
    "uamqp.async_ops.connection_async",
    "uamqp.async_ops",
    "uamqp.authentication",
    "uamqp.c_uamqp",
    "uamqp.connection",
    "uamqp.receiver",
    "uamqp.async_ops.session_async",
    "uamqp.sender",
    "uamqp.client",
    "azure.identity._persistent_cache",
    "azure.servicebus.aio._base_handler_async",
    "azure.servicebus._pyamqp.aio._cbs_async",
    "azure.servicebus._pyamqp.aio._connection_async",
    "azure.servicebus._pyamqp.aio._link_async",
    "azure.servicebus._pyamqp.aio._management_link_async",
    "azure.servicebus._pyamqp.aio._session_async",
    "azure.servicebus._pyamqp.aio._client_async"
]


def disable_unwanted_loggers():
    """
    Disables the unwanted loggers.
    """
    for logger_name in LOGGERS_FOR_ERRORS_ONLY:
        logging.getLogger(logger_name).setLevel(logging.ERROR)

    for logger_name in UNWANTED_LOGGERS:
        logging.getLogger(logger_name).disabled = True


def telemetry_processor_callback_function(envelope):
    envelope.tags['ai.cloud.role'] = 'api'
    envelope.tags['ai.application.ver'] = VERSION


class ExceptionTracebackFilter(logging.Filter):
    """
    If a record contains 'exc_info', it will only show in the 'exceptions' section of Application Insights without showing
    in the 'traces' section. In order to show it also in the 'traces' section, we need another log that does not contain 'exc_info'.
    """
    def filter(self, record):
        if record.exc_info:
            logger = logging.getLogger(record.name)
            _, exception_value, _ = record.exc_info
            message = f"{record.getMessage()}\nException message: '{exception_value}'"
            logger.log(record.levelno, message)

        return True


def initialize_logging(logging_level: int, correlation_id: Optional[str] = None, add_console_handler: bool = False) -> logging.LoggerAdapter:
    """
    Adds the Application Insights handler for the root logger and sets the given logging level.
    Creates and returns a logger adapter that integrates the correlation ID, if given, to the log messages.

    :param logging_level: The logging level to set e.g., logging.WARNING.
    :param correlation_id: Optional. The correlation ID that is passed on to the operation_Id in App Insights.
    :returns: A newly created logger adapter.
    """
    logger = logging.getLogger()

    disable_unwanted_loggers()

    if add_console_handler:
        console_formatter = logging.Formatter(fmt='%(module)-7s %(name)-7s %(process)-7s %(asctime)s %(levelname)-7s %(message)s')
        console_handler = logging.StreamHandler()
        console_handler.setFormatter(console_formatter)
        logger.addHandler(console_handler)

    try:
        # picks up APPLICATIONINSIGHTS_CONNECTION_STRING automatically
        if os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING"):
            azurelog_handler = AzureLogHandler()
            azurelog_handler.add_telemetry_processor(telemetry_processor_callback_function)
            azurelog_handler.addFilter(ExceptionTracebackFilter())
            logger.addHandler(azurelog_handler)
    except ValueError as e:
        logger.error(f"Failed to set Application Insights logger handler: {e}")

    config_integration.trace_integrations(['logging'])
    logging.basicConfig(level=logging_level, format='%(asctime)s traceId=%(traceId)s spanId=%(spanId)s %(message)s')
    Tracer(sampler=AlwaysOnSampler())
    logger.setLevel(logging_level)

    extra = {}

    if correlation_id:
        extra = {'traceId': correlation_id}

    adapter = logging.LoggerAdapter(logger, extra)
    adapter.debug(f"Logger adapter initialized with extra: {extra}")

    return adapter
